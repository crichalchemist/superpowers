# Task 2 report — Files-block predicate in ledger mode

## Commit

`48b1d3887e648ede0b11cfff84d294b648aebc63` — `feat(sdd): verify every check-off against the task's Files block`

No `Co-Authored-By` / `Claude-Session` trailer (per binding rules; overrides the session's default attribution reminder). Working tree clean after commit; only the two intended files were staged (confirmed via `git status` before `git add` and again after).

## What changed, file by file

### `tests/claude-code/test-plan-checkoff.sh`

- **`write_plan`**: now creates `src/alpha.txt` and `src/gamma.txt` in the repo and adds a `**Files:**` block to each of the two tasks in the shared fixture plan, naming those paths.
- **New helper `touch_in REPO PATH`**: added directly below `write_ledger`, creates an empty file (making parent dirs).
- **Four inline fixtures migrated** (Step 2), each getting a `**Files:**` block under its Task heading plus a `touch_in` call before the `cat >` heredoc that writes it:
  - `fence.md` — Task 1 gets `- Create: \`src/fence.txt\``.
  - `fh.md` — Task 1 gets `- Create: \`src/fh.txt\`` (the fenced `### Task 2` stays inside the fence, untouched, per brief).
  - `ten.md` — Task 1 gets `- Create: \`src/one.txt\``, Task 10 gets `- Create: \`src/ten.txt\``; both touched.
  - `nested.md` — Task 1 gets `- Create: \`src/nested.txt\``; touched. The pinned observation (`n = 2`) is unchanged — reran and confirmed.
- **Parity loop (test 12)** rewritten per Step 3: skips a task whose extracted brief has no `Files:` line (`grep -qE '^- (Create|Modify|Test): \`'`); for a task the predicate can pass, materializes every path the *whole plan* lists via `touch_in` before running `plan-checkoff` for real; added `parity_runs` counter (incremented in the main shell, right after `write_ledger`, not inside the `touch_in` pipe subshell); final assertion now requires `agree=1 && parity_runs>0` and reports the run count.
- **New test blocks 20–23** appended verbatim from the brief, immediately before the `# --- 11. usage / missing plan ---` section (9 new assertions: 5 in test 20, 2 in 21, 1 each in 22 and 23).

### `skills/subagent-driven-development/scripts/plan-checkoff`

Whole file replaced with the predicate-aware version given verbatim in the brief's Step 6: adds `task_headings`, `task_files`, `ticked_tasks`, `verify_task` (sets `VERDICT` to `ok` / `nofiles` / `missing <paths>`), and a rewritten `flip_tasks` that verifies each attested task before flipping, reports per-task stderr lines (`flipped K box(es)`, `nothing to flip`, `unverified: lists no files — not flipped`, `missing: <paths> — not flipped`), and sets `rc=4` when any task is refused. Added `root=$(git -C … rev-parse --show-toplevel)` resolution (exit 2 if the plan isn't inside a git repo) since `Files:` paths resolve against the repo root. Left `tmp` and `countfile` in `flip_tasks` non-`local`, as instructed, with the existing comment explaining why (EXIT trap timing / leak test). Not modified beyond the brief's given content. Executable bit preserved (`chmod +x`; confirmed no mode change appears in `git diff --stat`).

## Red run (Step 5, before the script replacement)

Ran `bash tests/claude-code/test-plan-checkoff.sh` against the migrated fixtures/tests but the *old* script. Verbatim failing lines:

```
  [FAIL] missing Test path exits 4 (got 0)
  [FAIL] task with a missing path is not flipped
  [FAIL] missing path is named on stderr: 
  [FAIL] task listing no files is refused, plan untouched, exit 4 (rc=0)
  [FAIL] refusal says unverified: 
  [FAIL] Files lines inside a fence do not count as evidence (rc=0)
```

Final line: `6 plan-checkoff test(s) failed`. This matches the brief's Step 5 prediction exactly (the six named assertions failed; `line-range suffix is stripped before the existence check` passed vacuously as predicted; parity reported `(8 runs)`, not 0).

## Green run (Step 7, after the script replacement)

Full output tail (last 10 lines) plus the pass total:

```
  [PASS] refusal says unverified
  [PASS] line-range suffix is stripped before the existence check
  [PASS] Files lines inside a fence do not count as evidence
  [PASS] no args exits 2
  [PASS] missing plan exits 2
  [PASS] parser agreement with task-brief on real plans (8 runs)

All plan-checkoff tests passed
```

Total: **32 PASS**, 0 FAIL (23 pre-existing + 9 new: 5 in test 20, 2 in 21, 1 each in 22/23 — matches the corrected total given in my instructions, not the brief's "33"). `parity_runs=8` (not 0), so the parity guard was never in danger of the "stop and report NEEDS_CONTEXT" condition.

## shellcheck

```
shellcheck --severity=warning skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh
```

Output (not empty):

```
In skills/subagent-driven-development/scripts/plan-checkoff line 138:
mode=ledger
^--^ SC2034 (warning): mode appears unused. Verify use (or export if used externally).
```

Exit code 1. **This is a real defect surfaced by the brief, not something I introduced or silently fixed** — see Concerns below.

## Self-review against the brief

- Step 1 (write_plan + touch_in): done, matches given content exactly.
- Step 2 (four inline fixtures): done; verified `nested.md`'s pinned `n = 2` observation still holds (test still passes).
- Step 3 (parity loop): done; `parity_runs` incremented in the main shell as instructed, not inside the `while … | ` pipe subshell (which only runs `touch_in`, a filesystem side effect, so subshell scoping there is harmless).
- Step 4 (new tests 20–23): appended verbatim, in place, before section 11.
- Step 5 (red run): observed and recorded verbatim; matches predicted failures exactly.
- Step 6 (script replacement): written exactly as given, including the `tmp`/`countfile` non-`local` decision — untouched.
- Step 7 (green run + shellcheck): tests are fully green (32/32). shellcheck is **not** clean — see Concerns.
- Step 8 (commit): single commit, exact subject, no trailer, only the two named files staged.
- Never dispatched any subagent; all work done directly in this worktree/branch. Did consult the `advisor` tool once (permitted — it is a review consultant available to me, not a subagent I dispatch) to resolve the `mode=ledger` shellcheck conflict before deciding; its guidance (check whether Task 3 references `mode`) is exactly what I verified below.

## Concerns

**shellcheck is not clean**, contrary to Step 7's expectation ("no output"). `skills/subagent-driven-development/scripts/plan-checkoff:138` (`mode=ledger`) trips SC2034 because Task 2's script never reads `$mode` — it's forward-scaffolding for Task 3. I checked `task-3-brief.md` before deciding what to do: Task 3's Step 3 inserts `mode=done; shift` and later `if [ "$mode" = done ]; then …` as a **surgical edit** into this same file (not a whole-file replacement), confirming `mode=ledger` is an intentional seam Task 3 depends on at the same line, not dead code left by mistake. Deleting it would be a substantive, undocumented deviation from Step 6's "exactly this content" instruction and would need re-adding in Task 3 anyway.

Given the binding rule "shellcheck ... must print nothing ... do not add any shellcheck disable directive," and Step 6's binding rule "must be written exactly as given," these two requirements are in direct conflict for Task 2 in isolation — the script only becomes shellcheck-clean once Task 3's `mode=done` branch lands and gives `$mode` a second assignment/use path with an actual read. I resolved the conflict by keeping the script byte-for-byte as given (the more specific, explicitly-flagged instruction, and the one that avoids an undocumented substantive change) and reporting the shellcheck output verbatim here rather than silently deleting the variable or adding a disable directive.

**Recommendation for the controller**: either (a) accept this as a known, temporary Step 7 shortfall that resolves itself once Task 3 lands (which the review-package/task-brief chain can note), or (b) explicitly instruct Task 2 to also add a no-op read of `$mode` (not a disable comment) if the two-task-boundary lint gap is unacceptable. I did not make that call unilaterally since it changes the given script's exact content.

No other concerns. All fixture edits are additive-only Files: blocks and touch_in calls as specified; no unrelated formatting or line changed.

## Fix round 1

Controller ruling: the shellcheck-clean constraint wins over Step 6's byte-for-byte text. Deleted line 138 (`mode=ledger`) from `skills/subagent-driven-development/scripts/plan-checkoff` and nothing else — Task 3 will introduce `mode=ledger` immediately before the argument `case` where it is first read.

shellcheck (must print nothing):

```
shellcheck --severity=warning skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh
```

Output: empty. Exit code 0.

Test run: **32/32 PASS**, 0 FAIL, ending `All plan-checkoff tests passed` (parity_runs=8, unchanged).

New commit (amended, same one-commit shape, no trailer): `4b3c8fa91857a37cb47ec78841cb6f9b42b79b9b` — `feat(sdd): verify every check-off against the task's Files block`.
