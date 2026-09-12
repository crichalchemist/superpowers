# SDD ledger — plan: docs/superpowers/plans/2026-09-11-task-checkoff-hook.md

Spec: docs/superpowers/specs/2026-09-11-todo-checkoff-hook-design.md (revision 2; read; binding).
Branch: task-checkoff-hook, worktree .claude/worktrees/task-checkoff-hook, base b8a8190 (develop after merging plan-checkoff).
Baseline: tests/claude-code/test-plan-checkoff.sh all pass (52); tests/hooks/test-session-start.sh PASSED.

## Pre-flight scan (2026-09-11)

| Pair / task | Produces vs consumes | Found |
|---|---|---|
| T2 / T3 (marker) | T2 `active-plan set` writes `<root>/.superpowers/sdd/active-plan` with `printf '%s\n' "$abs"`; T3 hook reads it with `head -n 1` and tests it with `-f` | consistent |
| T2 / T3 (test helper) | T3's test calls `$ACTIVE set docs/superpowers/plans/demo.md` from the repo root; T2's CLI is `set PLAN_FILE`, root from the plan's dir | consistent |
| T3 / T4 (refusal wording) | T4 prose promises a `missing:` or `unverified` line on refusal; T3 hook forwards plan-checkoff's `… — not flipped` lines, which carry exactly those words | consistent |
| T2 / T4 (commands) | T4 inserts `scripts/active-plan set PLAN_FILE` and `scripts/active-plan clear`; T2 defines `set`, `clear`, `show` | consistent |
| T1 self | probe checks regex the model's report shape; `check()` evals quoted strings; `find … -name 'in-*.json'` counts inputs | consistent; a failing probe stops the run by design (Step 3) |
| T2 self | 9 assertions in the test file vs the Step 2/4 counts | consistent (9); `.gitignore` with `*` self-ignores as sdd-workspace relies on |
| T2 self | Files block says `run-skill-tests.sh:78-83`; the array is at lines 76–81 on this branch | **line numbers off by two; instruction text ("directly after test-plan-checkoff.sh") governs — ruled below** |
| T3 self | 15 assertions; strings asserted (`Task 1: missing: src/alpha.txt`, `Task 3: unverified: lists no files`, `not executable`) vs plan-checkoff's and the hook's actual output | consistent |
| T3 self | test 10 sends `\"` inside task_subject; hook `field()` unescapes `\"` and `\\` before matching heading `Second "quoted" thing` | consistent |
| T3 self | test 7 whitespace/case subject vs `norm()` (lower, trim, collapse) | consistent |
| T3 self | hook uses `set -uo pipefail` (needs plan-checkoff's rc); active-plan uses `-euo` — Global Constraints allow both | consistent |
| T3 self | test 14 uses node for the manifest assertion | precedent: tests/hooks/test-session-start.sh |
| T4 self | seven anchors grep to exactly one hit each on this branch | verified pre-dispatch |
| Rubric | tests that pass before their fix | none after the corrected red-run predictions (a missing script exits 127 and fails even the silent cases) |

Ruling: Task 2's Files line `tests/claude-code/run-skill-tests.sh:78-83` names lines 76–81 on this branch; the brief carries the instruction text and the corrected range, the plan file is not edited for a two-line drift — cost if wrong: none, the suffix is stripped by the check-off and the edit is anchored on the array entry
Ruling: no eval task in the plan; the two csd cells run after the final review, by the controller, per the spec — cost if wrong: evidence arrives later than the build, not never
Ruling: my own session tracks the four plan tasks with TaskCreate under the `Task N: <name>` subject convention from Task 4, as a first use of the convention; no hook acts on them here (the installed plugin has none) — cost if wrong: none
Task 1: dispatched (BASE b8a8190, implementer sonnet, brief task-1-brief.md)
Task 1: implementer DONE, commit 4913425, probe 7/7 PASS (report task-1-report.md)
Task 1: review package review-b8a8190..4913425.diff; task reviewer dispatched (sonnet)
Task 1: complete (commits b8a8190..4913425, review clean)
Task 2: dispatched (BASE 4913425, implementer haiku, brief task-2-brief.md; carries ruling: runner array is at lines 76-81, insert directly after "test-plan-checkoff.sh")
Task 2: implementer DONE, commit 6ffaa17, 9/9 (controller re-ran: 9 PASS, shellcheck rc 0, no trailers, three files); note: red run showed 8 failures, not the 9 the plan predicted — test 6 (marker git-ignored) passes vacuously when nothing is written; a regression guard, not a defect
Task 2: review package review-4913425..6ffaa17.diff; task reviewer dispatched (sonnet)
Task 2: complete (commits 4913425..6ffaa17, review clean; reviewer confirmed the red-run reading: 8 genuine failures, test 6 vacuous; two Minor informational notes, none actionable)
Task 3: dispatched (BASE 6ffaa17, implementer sonnet, brief task-3-brief.md)
Task 3: implementer DONE, commit 594bb35, 15/15 (controller re-ran: 15 PASS, shellcheck rc 0, no trailers, three files, tree clean); red run all 15 failed as predicted
Ruling: the brief's field() used BRE alternation `\|` (a GNU extension BSD sed lacks); the implementer rewrote it as `sed -E` with POSIX ERE and added a one-line comment — accepted, the plan text was wrong for macOS and ERE is portable to both seds — cost if wrong: none, the 15 assertions exercise the same escapes on both forms
Ruling: implementer concern that test-task-checkoff.sh does not isolate HOME around git init — parked, not a fix-round item: only tests/hooks/test-session-start.sh isolates HOME; the three tests/claude-code suites (plan-checkoff, sdd-workspace, active-plan) do not, so the brief-verbatim test follows the claude-code convention; the task reviewer and final review weigh it — cost if wrong: a host gitconfig with commit.gpgsign or core.hooksPath could perturb the temp repos on another machine
Task 3: review package review-6ffaa17..594bb35.diff; task reviewer dispatched (sonnet)
Task 3: complete (commits 6ffaa17..594bb35, review clean; reviewer verified the sed -E ruling by diff and by test 10, probed Task 1 vs Task 10 disambiguation, and confirmed the parked HOME note stays Minor; one Minor coupling note on the not-flipped grep — carried to final review)
Task 4: dispatched (BASE 594bb35, implementer sonnet, brief task-4-brief.md)
Task 4: implementer DONE_WITH_CONCERNS, commit d80b827 (controller checked: two SKILL.md files only, no trailers, tree clean); concern: one brief-verbatim line at the SDD teardown edit ran to 112 columns, implementer rewrapped the line break only, no wording change — treated as an observation; reviewer to confirm wording is verbatim
Task 4: review package review-594bb35..d80b827.diff; task reviewer dispatched (sonnet)
Task 4: complete (commits 594bb35..d80b827, review clean; reviewer verified all seven anchors verbatim, the rewrap carries no wording change, hook promises match hooks/task-checkoff, protected-content filter 0)
Final review: dispatched (opus), whole branch b8a8190..d80b827, package review-b8a8190..d80b827.diff
Final review: With fixes (final-review.md): 0 Critical, 1 Important (#1 gpgsign in test-active-plan fixture commit), 8 Minor; all four suites and shellcheck clean; check-off readiness verified by the reviewer (nine paths, all four tasks will flip)
Ruling: fix wave takes Important #1 and Minors #2 (clear outside a repo is noisy and rm -f targets /), #3 (\s in grep), #4 (refusal path through run-hook.cmd, suite becomes 16), #7 (async:false symmetry) — all small, all inside the plan's Files blocks — cost if wrong: one extra commit to revert
Ruling: parked Minor #5 (comment in plan-checkoff noting the not-flipped dependency) — plan-checkoff is outside this plan's Files, a follow-up on develop — cost if wrong: a future wording change degrades to forwarding whole output, the right failure mode
Ruling: parked Minor #6 (duplicate headings unreachable), #8 (no EXIT traps, matches test-plan-checkoff), #9 (ragged rewrap, cosmetic), Rec 3 (field() whitespace tolerance) — none changes behaviour on the pinned harness; noted for the next spec revision — cost if wrong: none now
Ruling: the test-count deviation from the plan (15 -> 16 hook assertions, 9 -> 10 active-plan) is recorded here rather than by editing the plan file — cost if wrong: none, counts are not check-off inputs
Final fix wave: dispatched (BASE d80b827, implementer sonnet, brief final-fixwave.md)
Final fix wave: implementer DONE, commit d57945b (controller re-ran: active-plan 10/10, hook 16/16, plan-checkoff all pass, session-start PASSED; four files; no trailers); correction: the fix brief claimed an existing ceilinged outside-git test to copy — none existed, the implementer built the GIT_CEILING_DIRECTORIES technique and replayed the new assertion red against the pre-fix script
Final fix wave: review package review-d80b827..d57945b.diff; scoped re-review dispatched (sonnet)
Final fix wave: re-review clean (final-rereview.md), F1-F5 addressed, no new issues; red/green of the new clear assertion reproduced by the reviewer
Final review: clean at d57945b (b8a8190..d57945b, 5 commits). Teardown: plan-checkoff ledger mode, active-plan clear, archive to docs/superpowers/ledgers/2026-09-11-task-checkoff-hook/, delete workspace
