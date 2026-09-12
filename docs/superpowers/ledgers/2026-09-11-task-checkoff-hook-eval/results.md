# task-checkoff hook eval — 2026-09-12

## Method

Four Claude Code sessions driven by claude-session-driver 4.0.0, one per cell, each in an
already-trusted toy repository (`/private/tmp/rfj-agent-tests/csd-arm/rep-{2..5}-workdir`) reset
with `reset-toy.sh`: back to `main`, `greeter` recreated, and `.claude/settings.json` committed
with `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` (Task tools on for Claude 5 models) and the marketplace
superpowers 6.3.0 disabled. Same two-task greeter plan and the same prompts as the 2026-09-11
plan-checkoff eval (`prompt-ep.md`, `prompt-sdd.md`). Worker model sonnet; SDD implementers
haiku, reviewers sonnet, as the prompt directs.

Skill copies, loaded with `--plugin-dir` from a `git archive` of `task-checkoff-hook` at
`d57945b`:

- **hook + both** (`plugin-both`): the branch as shipped. The `TaskCompleted` hook is registered
  in `hooks/hooks.json`; the skills also keep their explicit check-off (`plan-checkoff --done N`
  in executing-plans, ledger-mode `plan-checkoff PLAN_FILE` at SDD teardown).
- **hook alone** (`plugin-alone`): the same tree with the explicit check-off removed by
  `make-alone.js` (executing-plans step 2.4 loses its `--done N` instruction; SDD teardown loses
  the ledger-mode run). Eval artifact, never shipped. The SDD setup bullet that reconciles from the
  ledger stays; on a fresh plan it is a no-op and the measurement counts its calls.

Measurement: `measure2.sh` — box counts in the plan on disk, deliverables, tests, commit count,
whether the plan file was committed, whether the marker was cleared, `--verify` from the plugin
copy, and from the session transcript: skill directories that answered, TaskCreate subjects,
TaskUpdate completions, Bash `--done` / `--verify` / ledger-mode calls, `active-plan set|clear`
calls, hook refusals fed back (`not flipped`), and a timeline of those events in transcript
order. Hand edits of the plan were ruled out by grepping each transcript for Edit/Write/sed
calls naming the plan file (0 in every cell). The no-hook baseline is the 2026-09-11 "after" row
(10/10 via prose `--done` calls, plan left uncommitted in executing-plans).

Cell → worker → toy: `cells.txt`. Raw measurements: `run-*.txt`.

## Results

| Skill | Cell | `- [ ]` | `- [x]` | deliverables | tests | TaskCreate subjects | TaskUpdate completed | Bash `--done` | ledger-mode | refusals | plan committed | marker cleared |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| executing-plans | hook + both | 0 | 10 | 4 of 4 | 2 pass | `Task 1: greet.sh`, `Task 2: shout.sh` | 2 | 2 | 0 | 0 | yes | yes |
| executing-plans | hook alone | 0 | 10 | 4 of 4 | 2 pass | `Task 1: greet.sh`, `Task 2: shout.sh` | 2 | 0 | 0 | 0 | yes | yes |
| subagent-driven-development | hook + both | 0 | 10 | 4 of 4 | 2 pass | `Task 1: greet.sh`, `Task 2: shout.sh` | 2 (+1 failed retry) | 0 | 2 (both flipped 0) | 0 | yes | yes |
| subagent-driven-development | hook alone | 0 | 10 | 4 of 4 | 2 pass | `Task 1: greet.sh`, `Task 2: shout.sh` | 2 | 0 | 1 (flipped 0) | 0 | yes | yes |

Columns: `TaskUpdate completed` counts calls with `status: completed`; `ledger-mode` counts
`plan-checkoff PLAN_FILE` runs and what each reported flipping; `refusals` counts
`plan-checkoff: Task N: … — not flipped` lines fed back to the model.

## Observations

**executing-plans, hook + both.** Order per task was prose first: `plan-checkoff --done N`, then
`TaskUpdate completed` (transcript lines 124→134 and 159→168). The hook then ran against an
already-ticked task and stayed silent; no refusals, no double work visible to the model. The
worker set the marker at step 1.5 and cleared it at Step 3, and committed the ticked plan — the
uncommitted-plan gap from the 2026-09-11 run is closed by the new Step 3 sentence.

**executing-plans, hook alone.** 10/10 with zero `--done` calls, zero ledger-mode calls, and no
hand edits: the only commands naming the plan were `active-plan set`, `--verify`, `git diff`, and
the commit. The boxes were ticked by the plugin-level `TaskCompleted` hook firing on the two
`TaskUpdate completed` calls (lines 123 and 201). This is the composition the final review said
was unproven — a plugin-supplied `TaskCompleted` entry, through `run-hook.cmd`, in a real session
against a `--plugin-dir` copy — and it works end to end. Spec success criterion for hook-alone
met on this skill.

**subagent-driven-development, hook + both.** The controller created the two tasks with the
exact `Task N: <name>` subjects, set the marker before Task 1, and completed each task with
TaskUpdate after its review (lines 204, 271). At teardown it ran ledger-mode `plan-checkoff` twice
(lines 319 and 376); both reported `checked off 0 task(s), 0 box(es)` — every box was already
ticked by the hook when the ledger reconcile ran. So in SDD the hook fires first by construction
(the ledger pass is teardown-only) and the prose backstop was idle. One extra `TaskUpdate
completed` for task 1 at line 403 came back `Task not found` (the finishing skill's session had
no such task); no hook ran for it. The ticked plan was committed (`chore: check off greeter plan
tasks`). No refusals: both tasks' `Files:` paths existed at completion time, as the SDD loop
guarantees (review precedes completion).

**subagent-driven-development, hook alone.** 10/10 with zero `--done` calls and no hand edits.
The one `plan-checkoff` run in the transcript (line 314, after both completions) reported
`checked off 0 task(s)`: the hook had ticked everything at lines 196 and 258. The same skill copy
also drove `requesting-code-review` for the final review, as the prompt's model directions asked.
Spec success criterion for hook-alone met on this skill too.

**Across all four cells.** No incorrect blocks (0 refusals, and every refusal would have been
wrong since all deliverables existed). The marker was set and cleared in every cell; no
`.superpowers/sdd/active-plan` was left behind. The subject convention held in 8 of 8 TaskCreate
calls that named a plan task (`Task 1: greet.sh`, `Task 2: shout.sh`, byte-exact to the plan's
headings), so the silent no-match path (final review Recommendation 1) was never taken here; a
larger plan with longer task names is where that risk lives, and the prose `--done`/ledger paths
remain as the backstop under D1.

**What this does not show.** Two tasks, short names, sonnet workers. The refusal path (exit 2
blocking a completion, `missing:` line fed back) was exercised by the branch's own test suite
(`test-task-checkoff.sh` tests 3–5 and 16, through `run-hook.cmd`) but not in a live session,
because no worker tried to complete a task whose files were missing.

## Environment

Claude Code 2.1.269 (workers, `--model sonnet`), claude-session-driver 4.0.0, macOS 13
(Darwin 22.6.0), bash 3.2 for the toy scripts. Plugin under test: `task-checkoff-hook` at
`d57945b`. The `.serena/` directories and `.gitignore` edits seen in the 2026-09-11 run come from a
globally installed plugin in the worker sessions and are unrelated to the skill under test.
