# Task 4 review: skill edits

### Spec Compliance

All seven anchored edits confirmed present at HEAD with brief-verbatim inserted text (whitespace/line-wrap collapsed for comparison; commit `d80b827`).

1. ✅ SDD (a) — workspace bullet append. `skills/subagent-driven-development/SKILL.md:140-141` reads "...never yours to read or write. Then run `scripts/active-plan set PLAN_FILE`, which names this plan to the task-completion check-off hook." — matches brief word-for-word.
2. ✅ SDD (b) — TaskCreate/`Task N` paragraph. `skills/subagent-driven-development/SKILL.md:162-166` matches brief verbatim, including the `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` gate sentence; "If the plan names a Spec..." tail (unchanged) follows correctly.
3. ✅ SDD (c) — "mark the task complete" + hook-refusal sentence. `skills/subagent-driven-development/SKILL.md:450-455` matches brief verbatim.
4. ✅ SDD (d) — teardown sentence + `active-plan clear`. `skills/subagent-driven-development/SKILL.md:494-496` matches brief verbatim. The implementer's reported rewrap of the following sentence ("Inspect the resulting `git diff` of the" / "plan before committing:...") was verified word-for-word against the pre-edit line via whitespace-collapsed diff of removed vs. added text: the only substantive change is the inserted ", then `scripts/active-plan clear`" clause; every other word, including the trailing "Inspect the resulting `git diff` of the" fragment, is identical, only relocated across the line boundary. No wording drift.
5. ✅ EXEC (a) — Step 1 item 5 TaskCreate/`active-plan set`/env-var text. `skills/executing-plans/SKILL.md:23-27` matches brief verbatim.
6. ✅ EXEC (b) — Step 2 item 4 "the task" + hook-refusal sentence. `skills/executing-plans/SKILL.md:35-41` matches brief verbatim.
7. ✅ EXEC (c) — Step 3 verify bullet + `active-plan clear`/commit sentence. `skills/executing-plans/SKILL.md:46-49` matches brief verbatim.

Anchor re-grep on HEAD: pre-edit anchors that were replaced (`create a$`, `Then mark the todo complete and move on`, `Create todos for the plan items and proceed`, `Mark as completed — the todo, and the plan file`) no longer match, as expected. Anchors that were only appended to (`scripts/sdd-workspace PLAN_FILE` at line 137, `Before deleting the workspace, run` at line 494, `plan-checkoff --verify PLAN_FILE` at executing-plans line 46) still resolve to exactly one place each, with the new text beside them.

Hook-promise check: read `hooks/task-checkoff`. On exit 4 from `plan-checkoff --done N`, it forwards the `grep 'not flipped'` line (of the form "...missing: ... — not flipped" / "...unverified: ... — not flipped") to stderr and exits 2, which Claude Code surfaces and keeps the task open — matches the prose's "`missing:` or `unverified` line says why" and "a refused completion means the task is not done." On a subject/heading mismatch, missing marker, or unparseable input the hook exits 0 silently — the new prose makes no promise for that case, so no overreach.

Command paths named in the prose resolve correctly relative to each skill's directory, matching the existing `scripts/sdd-workspace` convention: `scripts/active-plan set|clear` (bare, from `subagent-driven-development/SKILL.md`) and `../subagent-driven-development/scripts/active-plan set|clear` (from `executing-plans/SKILL.md`) both exist and are executable at those relative paths.

`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` / "Claude 5 models" gate sentence is present in both files: `subagent-driven-development/SKILL.md:165` and `executing-plans/SKILL.md:26`.

Global constraints, all verified directly:
- `git diff --stat 594bb35 d80b827` touches only the two named SKILL.md files (13 and 25 lines changed respectively).
- `git diff -U0` on `subagent-driven-development/SKILL.md` produces exactly 4 hunks, one per edit (a)-(d).
- Protected-content grep, applied with the brief's exact filter (`grep -E '^[-+]' | grep -v '^[-+]{3}' | grep -ciE 'red flag|rationaliz|human partner'`) on the two files' diff: **0** matches. (An unfiltered grep over the raw diff text hits 1 — an unchanged context line, "Raise them with your human partner before starting" — confirming the filter is required and the report's claim holds under it.)
- `git diff --ignore-all-space --ignore-blank-lines` produces the same changed-line count (42) as the plain diff — no whitespace-only or blank-line drift hiding in the hunks.
- One commit (`d80b827`), subject exactly `feat(skills): name the active plan and the Task N subject so the check-off hook can match`, no body, no `Co-Authored-By` or other trailer. Working tree clean. Branch has no upstream configured — not pushed.
- Test suites re-run and all pass: `tests/hooks/test-task-checkoff.sh`, `tests/claude-code/test-active-plan.sh`, `tests/claude-code/test-plan-checkoff.sh` — all print "All ... passed".

### Code Quality

None.

The single deviation (rewrapping the line the brief's own 112-column insertion pushed over the file's convention) is disclosed in the report, confined to one line, verified above to carry no wording change, and necessary to keep the paragraph within the file's existing wrap convention — not a quality defect.

### Verdict

**Spec:** ✅ met — all seven edits present verbatim at their anchors, hook promises kept, command paths resolve, gate sentence present in both files, global constraints (file scope, hunk count, protected content, no whitespace drift, single clean unpushed commit, passing test suites) all independently verified.

**Quality:** approved — no Critical or Important items.
