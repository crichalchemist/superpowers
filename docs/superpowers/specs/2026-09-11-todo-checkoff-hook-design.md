# TodoWrite check-off hook — design

**Date:** 2026-09-11
**Status:** approved in brainstorming; awaiting the written-spec review
**Builds on:** `docs/superpowers/specs/2026-09-11-plan-checkoff-verify-design.md` and the
`plan-checkoff` script it specifies (fork PR #2). Nothing here changes that script; this design
adds one more caller of its `--done` mode.

## Problem

Agents mark todos complete far more reliably than they run a bash command a skill told them
about. The `plan-checkoff --done N` step added to `executing-plans` works on a two-task plan
(eval, 2026-09-11: 10/10 boxes), but the only long-plan data point on a prose-driven check-off
(upstream #808, tested by a reader on a 120k-token plan) ticked one task. New habits decay with
plan length; the todo habit is installed by the harness itself and does not.

TodoWrite state is not on disk in any stable form (the todos directory on the reference machine
is empty; the format is undocumented). The only reliable channel is the tool call, so the
mechanism is a `PostToolUse` hook.

## Decisions

- **D1. The hook is an additional attestation source, not a replacement.** Both skills keep the
  `--done N` instruction (ruling: "both"). A todo says a task is claimed done; the `Files:`
  predicate in `plan-checkoff` still decides whether it flips. The hook adds no verification of
  its own and no prose of its own.
- **D2. A marker file names the active plan.** `<repo-root>/.superpowers/sdd/active-plan`, one
  line, the plan's absolute path, written by a new sibling script `active-plan` at skill setup
  and cleared at teardown. That directory already exists for SDD runs and already self-ignores
  with `*`, so nothing tracked in the target repository changes.
- **D3. The hook matches the whole todo title, not just the number.** A todo qualifies only if
  its status is `completed` and its text is `Task N: <name>` where `<name>` equals the plan's
  own `### Task N: <name>` heading, case-insensitive, whitespace-trimmed. This is the guard
  against a stale marker steering another plan's todos into the wrong file.
- **D4. Refusals are reported once, as feedback.** A refusal (exit 4 from `plan-checkoff`) is
  returned with exit 2 so Claude Code feeds it back to the model on the tool call it just made;
  an identical refusal on a later call is silent. Flips are returned as `additionalContext`.
  Everything else is silent.
- **D5. Claude Code only.** The hook is registered in `hooks/hooks.json`; `hooks-cursor.json`
  is untouched. The portable path stays the SDD ledger and `--done N`.

## Components

### `skills/subagent-driven-development/scripts/active-plan`

```
active-plan set PLAN_FILE    # resolve PLAN_FILE to an absolute path, write the marker, print it
active-plan clear            # remove the marker and its refusal log; silent if absent
active-plan show             # print the marker's path; exit 1 if none
```

- Resolves the repository root the way `sdd-workspace` does (`git rev-parse --show-toplevel`),
  creates `.superpowers/sdd/` and its self-ignoring `.gitignore` if absent, writes
  `.superpowers/sdd/active-plan`.
- `set` on a missing plan file exits 2 with a message. `clear` also removes
  `.superpowers/sdd/active-plan.refused` (see the hook's state below).
- One marker per repository root. Two plans executing in the same working tree race on it, last
  `set` wins; that is the same limit the SDD ledger has and is documented, not solved. Parallel
  worktrees have separate roots and are unaffected.

### `hooks/todo-checkoff`

Extensionless bash script, like `session-start`, run through `hooks/run-hook.cmd`. Registered as:

```json
"PostToolUse": [
  {
    "matcher": "TodoWrite",
    "hooks": [
      { "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" todo-checkoff",
        "shell": "bash",
        "async": false }
    ]
  }
]
```

**Input.** The PostToolUse JSON on stdin: `cwd`, `tool_name`, `tool_input` (for TodoWrite, the
full todo list; each entry has `content` and `status`).

**Steps.**

1. Read stdin. Resolve the repository root from `cwd`. If `.superpowers/sdd/active-plan` is
   absent, or names a file that no longer exists, exit 0 with no output.
2. Split `tool_input.todos` into entries and keep those with `"status":"completed"` whose
   `content` matches `^Task ([0-9]+):? *(.*)$`. The parse is bash and sed, deliberately shallow;
   anything that does not parse is treated as no match. The hook sees the whole list on every
   call and relies on `--done`'s idempotence for tasks flipped earlier.
3. For each candidate, compare its `<name>` with the plan's `### Task N: <name>` heading
   (case-insensitive, trimmed). No heading, or a different name, means skip.
4. For each surviving N in ascending order, run
   `"$CLAUDE_PLUGIN_ROOT/skills/subagent-driven-development/scripts/plan-checkoff" --done N PLAN`
   and act on its exit code as below. One call per N so a single failure cannot abort the rest.

**Output, by `plan-checkoff` exit code.**

| `plan-checkoff` | hook |
|---|---|
| 0, one or more boxes flipped | exit 0; stdout carries `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"<the flip lines>"}}`; the task's entry in the refusal log is removed |
| 0, nothing to flip (already ticked) | silent |
| 4, refused (missing path, or no `Files:` lines) | if the refusal text differs from the task's entry in the refusal log: record it, print the refusal lines to stderr, exit 2. Otherwise silent, exit 0 |
| 2 or 3 (usage, plan outside git, workspace trouble) | one line to stderr, exit 0 |
| `plan-checkoff` missing or not executable | one line to stderr, exit 0 |

The refusal log is `.superpowers/sdd/active-plan.refused`, one line per task,
`N<TAB><refusal text>`. It exists so a task that cannot be flipped (an older plan with no
`Files:` block) is reported once, not on every TodoWrite call for the rest of the run.

PostToolUse cannot undo the todo. The todo stays completed, the box stays unticked, and the
agent reads why in its next turn. That immediacy is the point of the design.

**Cost when idle.** Every TodoWrite call in every session pays a `git rev-parse` and a file
existence test, then exits. No plan is read unless a marker exists.

### Skill edits

Four lines per skill, at anchors that exist today on the `plan-checkoff` branch. No change to
Red Flags tables, rationalization lists, or "human partner" language.

`skills/subagent-driven-development/SKILL.md`

1. Setup, workspace bullet: after "run this skill's `scripts/sdd-workspace PLAN_FILE`", add
   "then `scripts/active-plan set PLAN_FILE`, which names this plan to the TodoWrite check-off
   hook."
2. Setup, "create a todo per task": becomes "create a todo per task, titled with the plan's own
   heading, `Task N: <name>`, so the check-off hook can match it."
3. Task loop, "Then mark the todo complete and move on": add "On Claude Code, marking it runs
   `plan-checkoff --done N` through a hook; a `missing:` or `unverified` line in reply means the
   task is not done, whatever the review said."
4. Teardown, where `plan-checkoff` runs before the workspace is deleted: add "and
   `scripts/active-plan clear`."

`skills/executing-plans/SKILL.md`

1. Step 1, "Create todos for the plan items and proceed": becomes "Create one todo per task,
   titled with the plan's heading, `Task N: <name>`; run
   `../subagent-driven-development/scripts/active-plan set PLAN_FILE`; proceed."
2. Step 2.4 keeps the `--done N` instruction. Add: "Marking the todo runs the same check-off
   through a hook on Claude Code; treat a `missing:` line from either as the task not being
   done."
3. Step 3, after `--verify`: add "then `active-plan clear`."
4. Step 3, same anchor: add "commit the plan file with the check-off." (Closes the gap the
   2026-09-11 eval surfaced: the executing-plans cell left its ticked plan uncommitted.)

## Failure modes and known limits

| Situation | Behaviour |
|---|---|
| No marker | exit 0, silent |
| Marker names a deleted or moved plan | treated as no marker; `active-plan show` reveals it |
| Stale marker from an abandoned plan, new plan's todos | names do not match the old plan's headings; silent (D3) |
| Todo list cannot be parsed, or content contains escaped quotes | no matches, silent |
| Subagent titles a todo with the exact heading and completes it | the box may flip before the task review; it is still backed by files on disk, and the ledger-mode run at teardown reconciles. Known limit. |
| Concurrent writes from a subagent and the controller | `plan-checkoff` rewrites atomically and re-reads the plan per call; the later writer's view wins, both evidence-backed |
| Two plans in one working tree | last `active-plan set` wins; documented limit shared with the ledger |
| Harness timeout | not reachable: one `rev-parse`, a file read, at most a few sub-second calls |
| Windows | same polyglot runner and git-bash assumptions as `session-start` |

The hook never writes the marker, never edits a todo, never infers a task from anything but a
matching completed title, and never exits non-zero except the deliberate exit 2 on a first-time
refusal.

## Tests

Two new files, both added to the array in `tests/claude-code/run-skill-tests.sh`. Hermetic
`new_repo` fixtures, no host environment leakage, `shellcheck --severity=warning` clean with no
disable directives.

`tests/claude-code/test-active-plan.sh`

- `set` writes the absolute path and prints it
- `set` on a missing plan exits 2
- `show` exits 1 with no marker, 0 with the path once set
- `clear` is idempotent and removes the refusal log
- the marker never appears in `git status --porcelain`

`tests/claude-code/test-todo-checkoff.sh` (drives `hooks/todo-checkoff` with crafted stdin JSON)

- no marker: exit 0, no output
- matching completed todo, files present: box flipped; stdout is the `additionalContext` JSON and contains the flip line
- matching todo, file missing: exit 2, `missing:` on stderr, box unflipped, refusal log has the entry
- same refusal again: exit 0, silent
- refusal text changed (a different missing path): reported again
- a later flip removes the task's refusal entry
- number matches, name differs: silent, unflipped
- status `pending` or `in_progress`: nothing
- already ticked: silent, exit 0
- two matching todos, one refused: the other still flips
- malformed JSON: exit 0, silent
- content with escaped quotes: parsed or ignored, never an error
- marker names a deleted plan: exit 0, silent
- `hooks/hooks.json` contains a `PostToolUse` entry whose matcher is `TodoWrite` and whose command routes through `run-hook.cmd todo-checkoff`

`plan-checkoff` does not change; its suite (52 assertions) is the regression floor.

## Eval

Same rig as the 2026-09-11 check-off eval (`docs/superpowers/ledgers/2026-09-11-plan-checkoff-eval/`
on the `plan-checkoff` branch): the two-task toy plan, the same prompts, claude-session-driver
workers with `--plugin-dir`, the marketplace copy disabled, measured by the same script plus one
new count from the transcript: flips attributed to the hook (`additionalContext` or hook stderr)
versus flips attributed to a Bash `--done` call. Two cells per skill; tonight's "after" cells are
the no-hook baseline.

| Cell | Skill copy | Question |
|---|---|---|
| hook + both | this spec as shipped | Does the hook coexist with the prose without double-reporting? Which fires first per task? |
| hook alone | same, with the `--done` sentence removed from the skill copy (an eval artifact, never shipped) | Does the todo habit alone carry the check-off to 10/10? |

Success: hook-alone reaches 10/10 with zero Bash `--done` calls; hook-plus-both reaches 10/10
with no exit-2 output. If hook-alone falls short the design still ships under D1, and the
number goes into the #1075 thread either way.

## Out of scope

- Any change to `plan-checkoff` itself.
- Cursor, Codex, Gemini, Pi, or OpenCode hook manifests.
- Reading TodoWrite state from disk.
- Undoing or editing a todo from the hook.
- Multiple concurrent plans in one working tree.

## Sequencing

This lands on `develop` after fork PR #2 (`plan-checkoff`) merges, because the skill anchors and
the `--done` mode it calls are on that branch. Build it with subagent-driven-development from a
plan written against this spec; archive the ledger per `.claude/CLAUDE.md`.
