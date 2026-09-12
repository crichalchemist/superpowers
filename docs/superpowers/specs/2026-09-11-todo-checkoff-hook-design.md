# Task-completion check-off hook — design

**Date:** 2026-09-11 (revision 2, same day)
**Status:** approved in brainstorming; awaiting the written-spec review
**Builds on:** `docs/superpowers/specs/2026-09-11-plan-checkoff-verify-design.md` and the
`plan-checkoff` script it specifies (fork PR #2). Nothing here changes that script; this design
adds one more caller of its `--done` mode.

**Revision 2 supersedes revision 1.** Revision 1 hooked `PostToolUse` on TodoWrite. Research on
Claude Code 2.1.269 found that TodoWrite is a legacy tool, off by default; the current family is
TaskCreate / TaskUpdate / TaskList / TaskGet; and the harness ships a `TaskCompleted` hook event
whose exit 2 blocks the completion. The mechanism moves to that event. What it changes is
listed under "Differences from revision 1" at the end.

## Problem

Agents mark tasks complete far more reliably than they run a bash command a skill told them
about. The `plan-checkoff --done N` step added to `executing-plans` works on a two-task plan
(eval, 2026-09-11: 10/10 boxes), but the only long-plan data point on a prose-driven check-off
(upstream #808, tested by a reader on a 120k-token plan) ticked one task. New habits decay with
plan length; the task-tracking habit is installed by the harness itself and does not.

A second finding shapes the design. On Claude 5 models the Task tools are off unless
`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` is set (they are on by default for Claude 4-era models), and
TodoWrite is off unless `CLAUDE_CODE_ENABLE_TASKS=0`. In the four 2026-09-11 eval sessions and
in the controller's own session no task tool existed at all, so the skills' "create a todo per
task" line was dead text. Any design that leans on the habit has to name the gate.

## Decisions

- **D1. The hook is an additional attestation source, not a replacement.** Both skills keep the
  `--done N` instruction (ruling: "both"). A completed task says the work is claimed done; the
  `Files:` predicate in `plan-checkoff` still decides whether the boxes flip. The hook adds no
  verification of its own and no prose of its own.
- **D2. A marker file names the active plan.** `<repo-root>/.superpowers/sdd/active-plan`, one
  line, the plan's absolute path, written by a new sibling script `active-plan` at skill setup
  and cleared at teardown. That directory already exists for SDD runs and already self-ignores
  with `*`, so nothing tracked in the target repository changes.
- **D3. The hook matches the whole task subject, not just the number.** A completion qualifies
  only if `task_subject` is `Task N: <name>` where `<name>` equals the plan's own
  `### Task N: <name>` heading, case-insensitive, whitespace-trimmed. This is the guard against a
  stale marker steering another plan's tasks into the wrong file.
- **D4. A refusal blocks the completion.** When `plan-checkoff --done N` exits 4, the hook exits
  2 with the refusal lines on stderr. Claude Code then refuses to mark the task completed and
  feeds the stderr to the model as feedback on the call it just made. The task stays
  `pending` or `in_progress` until the files exist. A successful flip is silent to the model; the
  ticked plan is the record.
- **D5. Claude Code only.** The hook is registered in `hooks/hooks.json`; `hooks-cursor.json` is
  untouched. The portable path stays the SDD ledger and `--done N`.
- **D6. The Task tools gate is named, not hidden.** Both skills' setup text says the mechanism
  needs the Task tools, on by default for Claude 4-era models and enabled on Claude 5 models by
  `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in a settings `env` block. The fork sets it in the user's
  settings; upstream would decide for itself.

## Verified harness contract (Claude Code 2.1.269, probed 2026-09-11)

A project-level `TaskCompleted` hook in a scratch repository, with the env set, on Sonnet 5:

- The session had TaskCreate, TaskUpdate, TaskList, TaskGet and no TodoWrite.
- The hook fired on each TaskUpdate to `completed`. Its stdin was one JSON object with
  `session_id`, `transcript_path`, `cwd`, `prompt_id`, `hook_event_name` (`TaskCompleted`),
  `task_id`, `task_subject`, `task_description`. The documented `teammate_name` and `team_name`
  fields were absent outside a team.
- Exit 0 allowed the completion. Exit 2 with a stderr line blocked it: `TaskList` afterwards
  showed the task still `pending`, and the model's report quoted the stderr verbatim as
  "TaskCompleted hook feedback".
- The hook's environment carried `CLAUDE_PROJECT_DIR` and `CLAUDE_CODE_SESSION_ID`.
- Documentation (hooks reference): `TaskCompleted` supports exit 2 and JSON
  `{"continue": false, "stopReason": …}`; it does not support `additionalContext`.

The build's first task re-runs this probe against the installed version and stops if any of
the above has changed.

## Components

### `skills/subagent-driven-development/scripts/active-plan`

```
active-plan set PLAN_FILE    # resolve PLAN_FILE to an absolute path, write the marker, print it
active-plan clear            # remove the marker; silent if absent
active-plan show             # print the marker's path; exit 1 if none
```

- Resolves the repository root the way `sdd-workspace` does (`git rev-parse --show-toplevel`),
  creates `.superpowers/sdd/` and its self-ignoring `.gitignore` if absent, writes
  `.superpowers/sdd/active-plan`.
- `set` on a missing plan file exits 2 with a message.
- One marker per repository root. Two plans executing in the same working tree race on it, last
  `set` wins; that is the same limit the SDD ledger has and is documented, not solved. Parallel
  worktrees have separate roots and are unaffected.

### `hooks/task-checkoff`

Extensionless bash script, like `session-start`, run through `hooks/run-hook.cmd`. Registered as:

```json
"TaskCompleted": [
  {
    "hooks": [
      { "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" task-checkoff",
        "shell": "bash" }
    ]
  }
]
```

**Input.** The `TaskCompleted` JSON on stdin; the fields used are `cwd` and `task_subject`.

**Steps.**

1. Read stdin. Extract `cwd` and `task_subject` with sed; if either is absent, exit 0 silently.
   Resolve the repository root from `cwd`. If `.superpowers/sdd/active-plan` is absent, or
   names a file that no longer exists, exit 0 silently.
2. Match `task_subject` against `^Task ([0-9]+):? *(.*)$`. No match: exit 0 silently.
3. Compare `<name>` with the plan's `### Task N: <name>` heading (case-insensitive, trimmed).
   No such heading, or a different name: exit 0 silently.
4. Run `"$CLAUDE_PLUGIN_ROOT/skills/subagent-driven-development/scripts/plan-checkoff" --done N PLAN`
   and act on its exit code.

**Output, by `plan-checkoff` exit code.**

| `plan-checkoff` | hook |
|---|---|
| 0 (boxes flipped, or nothing to flip because already ticked) | exit 0, silent; the completion proceeds |
| 4, refused (missing path, or no `Files:` lines) | the refusal lines on stderr, exit 2; the completion is blocked and the model reads the lines |
| 2 or 3 (usage, plan outside git, workspace trouble) | one line to stderr, exit 0; the completion proceeds |
| `plan-checkoff` missing or not executable | one line to stderr, exit 0; the completion proceeds |

Only a refusal blocks. A broken hook environment never holds a task hostage.

**Why no refusal log.** In revision 1 the hook saw the whole todo list on every call and had to
avoid repeating a refusal. `TaskCompleted` fires once per completion attempt, each attempt is a
fresh claim, and a blocked task cannot be "completed again" without the agent acting. Repeating
the refusal on a retry is correct, not noise.

**Cost when idle.** Sessions that never complete a task never run the hook. A completion in a
repository with no marker costs a `git rev-parse` and a file existence test.

### Skill edits

Four lines per skill, at anchors that exist on the `plan-checkoff` branch. No change to Red
Flags tables, rationalization lists, or "human partner" language.

`skills/subagent-driven-development/SKILL.md`

1. Setup, workspace bullet: after "run this skill's `scripts/sdd-workspace PLAN_FILE`", add
   "then `scripts/active-plan set PLAN_FILE`, which names this plan to the task-completion
   check-off hook."
2. Setup, "create a todo per task": becomes "create one task per plan task with TaskCreate,
   subject exactly the plan's heading, `Task N: <name>`, so the check-off hook can match it.
   (Claude 5 models need `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in a settings `env` block for the
   Task tools to exist.)"
3. Task loop, "Then mark the todo complete and move on": becomes "Then mark the task complete
   and move on. On Claude Code the completion runs `plan-checkoff --done N` through a hook; if
   the hook refuses, the task stays open and the `missing:` or `unverified` line says why,
   whatever the review said."
4. Teardown, where `plan-checkoff` runs before the workspace is deleted: add "and
   `scripts/active-plan clear`."

`skills/executing-plans/SKILL.md`

1. Step 1, "Create todos for the plan items and proceed": becomes "Create one task per plan
   task with TaskCreate, subject exactly the plan's heading, `Task N: <name>`; run
   `../subagent-driven-development/scripts/active-plan set PLAN_FILE`; proceed. (Claude 5 models
   need `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in a settings `env` block for the Task tools to
   exist.)"
2. Step 2.4 keeps the `--done N` instruction. Add: "Marking the task complete runs the same
   check-off through a hook on Claude Code; a refused completion means the task is not done."
3. Step 3, after `--verify`: add "then `active-plan clear`."
4. Step 3, same anchor: add "commit the plan file with the check-off." (Closes the gap the
   2026-09-11 eval surfaced: the executing-plans cell left its ticked plan uncommitted.)

## Failure modes and known limits

| Situation | Behaviour |
|---|---|
| Task tools absent from the session (Claude 5 without the env) | no completions, no hook runs; the `--done N` prose is the only check-off, as today |
| No marker | exit 0, silent |
| Marker names a deleted or moved plan | treated as no marker; `active-plan show` reveals it |
| Stale marker from an abandoned plan, new plan's tasks | names do not match the old plan's headings; silent (D3) |
| Subject cannot be parsed, or stdin is not the expected shape | silent exit 0 |
| Subagent creates a task with the exact heading and completes it | the box may flip before the task review; it is still backed by files on disk, and the ledger-mode run at teardown reconciles. Known limit. |
| Team session: `teammate_name` present | ignored; the subject match is the only criterion |
| Concurrent completions from a subagent and the controller | `plan-checkoff` rewrites atomically and re-reads the plan per call; the later writer's view wins, both evidence-backed |
| Two plans in one working tree | last `active-plan set` wins; documented limit shared with the ledger |
| Harness timeout | not reachable: one `rev-parse`, a file read, one sub-second call |
| Windows | same polyglot runner and git-bash assumptions as `session-start` |

The hook never writes the marker, never edits a task, never infers a task from anything but a
matching subject, and never exits non-zero except the deliberate exit 2 on a refusal.

## Tests

Two new files. The hook test lives beside the existing hook test in `tests/hooks/`; the
`active-plan` test beside the check-off test in `tests/claude-code/` and in the
`run-skill-tests.sh` array. Hermetic `new_repo` fixtures, no host environment leakage,
`shellcheck --severity=warning` clean with no disable directives.

`tests/claude-code/test-active-plan.sh`

- `set` writes the absolute path and prints it
- `set` on a missing plan exits 2
- `show` exits 1 with no marker, 0 with the path once set
- `clear` is idempotent
- the marker never appears in `git status --porcelain`

`tests/hooks/test-task-checkoff.sh` (drives `hooks/task-checkoff` with crafted stdin JSON, the
field set recorded above, `CLAUDE_PLUGIN_ROOT` pointed at the repo)

- no marker: exit 0, no output
- matching subject, files present: box flipped, exit 0, no output
- matching subject, file missing: exit 2, `missing:` on stderr, box unflipped
- matching subject, task lists no files: exit 2, `unverified` on stderr
- same refusal on a second attempt: exit 2 again (a retry is a fresh claim)
- number matches, name differs: silent, unflipped
- subject not in `Task N` form: silent
- already ticked: exit 0, silent
- malformed stdin, subject with escaped quotes, marker naming a deleted plan: exit 0, silent
- `plan-checkoff` path not executable: exit 0, one stderr line
- `hooks/hooks.json` contains a `TaskCompleted` entry whose command routes through
  `run-hook.cmd task-checkoff`

`plan-checkoff` does not change; its suite (52 assertions) is the regression floor.

## Eval

Same rig as the 2026-09-11 check-off eval (`docs/superpowers/ledgers/2026-09-11-plan-checkoff-eval/`
on the `plan-checkoff` branch): the two-task toy plan, the same prompts, claude-session-driver
workers with `--plugin-dir`, the marketplace copy disabled, `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in
the toy's committed project settings, measured by the same script plus two counts from the
transcript: TaskUpdate completions per plan task, and Bash `--done` calls. Two cells per skill;
the 2026-09-11 "after" cells are the no-hook baseline.

| Cell | Skill copy | Question |
|---|---|---|
| hook + both | this spec as shipped | Does the hook coexist with the prose? Which fires first per task? Any blocked completions, and were they correct? |
| hook alone | same, with the `--done` sentence removed from the skill copy (an eval artifact, never shipped) | Does the task-completion habit alone carry the check-off to 10/10? |

Success: hook-alone reaches 10/10 with zero Bash `--done` calls; hook-plus-both reaches 10/10
with no incorrect blocks. If hook-alone falls short the design still ships under D1, and the
number goes into the #1075 thread either way.

## Out of scope

- Any change to `plan-checkoff` itself.
- TodoWrite (legacy, off by default) and `PostToolUse` matching of any kind.
- `TaskCreated` enforcement of the subject convention.
- Cursor, Codex, Gemini, Pi, or OpenCode hook manifests.
- Reading task state from disk (`.claude/tasks/`, format undocumented).
- Multiple concurrent plans in one working tree.

## Sequencing

This lands on `develop` after fork PR #2 (`plan-checkoff`) merges, because the skill anchors and
the `--done` mode it calls are on that branch. Build it with subagent-driven-development from a
plan written against this spec; archive the ledger per `.claude/CLAUDE.md`.

## Differences from revision 1

| Revision 1 | Revision 2 |
|---|---|
| `PostToolUse` on TodoWrite; parse the whole todo list | `TaskCompleted` event; read `task_subject` |
| Refusal is feedback after the fact; the todo stays completed | Refusal blocks the completion; the task stays open |
| Refusal log to report once | Dropped: each completion attempt is a fresh claim |
| Flips returned as `additionalContext` | Flips silent; the ticked plan is the record |
| Skills say "create a todo per task" | Skills name TaskCreate, the exact subject, and the Task tools gate (D6) |
| Hook test in `tests/claude-code/` | Hook test in `tests/hooks/`, beside `test-session-start.sh` |
