# Task 4 Review — `--verify` audit mode

## Spec compliance: ✅ Met

| Requirement | Status | Evidence |
|---|---|---|
| Header usage line: `#   plan-checkoff --verify PLAN_FILE           audit: every ticked task must verify; writes nothing` | Met | diff line 24; script line 8, verbatim match. |
| Header exit-code 4 line extended | Met | diff lines 36-37; script line 20: `4 one or more attested tasks not flipped, or --verify found a ticked task that fails; others still processed`. |
| `usage()` line `echo "       plan-checkoff --verify PLAN_FILE" >&2` | Met | diff line 50; script line 33, verbatim, positioned between `--done` and `--print-range` usage lines as in the brief's snippet. |
| `--verify)` arm before `--done)` arm | Met | diff line 72 / script line 144: `--verify) mode="verify"; shift ;;` is the first arm in the `case`, immediately before `--done)`. |
| Verify block placed after `--done` block, before `# ---- ledger mode` banner | Met | script lines 186-200 sit directly after the `--done` block's closing `fi` (line 184) and directly before the ledger-mode banner (line 202). |
| Loop shape: `while … done < <(ticked_tasks "$plan")`, `rc` survives | Met | script lines 191-198 use process substitution, not a pipe; verified empirically that `rc` correctly reaches `exit "$rc"` after multiple loop iterations (see probe (d) below). |
| `mode="verify"` quoted, `[ "$mode" = "verify" ]` quoted, consistent with Task 3's style | Met | script lines 144, 188. |
| Tests 31-34 added, correct content and placement (before `# --- 11. usage / missing plan ---`) | Met | test file lines 392-422, directly before line 424's `# --- 11. ...` comment, matching the brief's instruction to append "before" that section (which literally still follows numerically, per existing test-file convention of appending new tests ahead of an out-of-order historical block). |
| `shellcheck --severity=warning` clean, no `disable` directives | Met | Ran `shellcheck --severity=warning skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh` at HEAD f35c130 — no output, exit 0. Diff contains no `shellcheck disable` comments. |
| `scripts/lint-shell.sh` run | Met | Ran `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh` — printed `Linting 2 shell files`, exit 0. |
| Commit subject exact match | Met | `/usr/bin/git show -s f35c130` → `feat(sdd): plan-checkoff --verify audits ticked tasks against their Files block`, verbatim match to the brief. No Co-Authored-By or other agent trailer present. |
| Full suite: 45 `[PASS]`, "All plan-checkoff tests passed" | Met | Ran `bash tests/claude-code/test-plan-checkoff.sh` at HEAD — 45 `[PASS]` lines, ends with `All plan-checkoff tests passed`. |

**Commit/tree confirmation:** `/usr/bin/git rev-parse HEAD` → `f35c130bd8f91f6909a6d3096cb330b5f9b36a1a`; `/usr/bin/git status` → `nothing to commit, working tree clean` (the only untracked file was this review itself, and `.superpowers/` is gitignored per `.gitignore:6`, confirmed with `git check-ignore -v`). All commands below (shellcheck, lint-shell, the full suite, and every probe) therefore ran against the exact reviewed commit, not an ahead/behind worktree.

## Task quality: Approved

Behavioral probes run against HEAD f35c130 in throwaway `new_repo`-style repos under a scratch directory (never touching the worktree):

- **(a) Ticked box only inside a fenced block** — task is correctly *not* audited: a plan with `**Files:** - Create: missing.txt` and the only `- [x]` inside a ` ```markdown ` fence produced `rc=0`, silent. Fences are correctly ignored by `ticked_tasks`.
- **(a2) Uppercase `- [X]`** — counts as ticked: same plan with `- [X]` (uppercase, unfenced) and a missing path produced `rc=4`, `verify: Task 1 ticked but missing: src/missing2.txt`.
- **(b) No Task headings at all** — a plan with only a top-level `#` heading and a ticked box (no `### Task N`) produced `rc=0`, silent — `ticked_tasks`'s `cur` never gets set, so no task context exists to report against.
- **(b2) Ticked box before the first Task heading** — produced `rc=0`, silent: the pre-heading tick has `cur=""` at that point and is never attributed to Task 1, and Task 1 itself has no ticked box in this fixture.
- **(c) mtime/checksum invariance on exit 4** — a plan with one ticked task whose Create path is missing: `cksum` and mtime were identical before and after a `--verify` run that exited 4. `--verify` writes nothing even on failure. This was extended beyond the plan file itself: `find "$r" -mindepth 1` before and after a `--verify` run that exited 4 produced an identical listing (empty diff), and an explicit `find "$r" -name '.superpowers' -o -name '.plan-checkoff*'` afterward returned nothing. So `--verify` creates neither an `sdd-workspace` ledger directory nor the `flip_tasks` temp files — consistent with the code: `exit "$rc"` at script line 199 returns before the ledger-mode block (line 204 onward, where `sdd-workspace` is invoked) is ever reached, and `flip_tasks` (the only caller of `mktemp`) is never called from the verify branch.
- **(d) rc survives the loop across two offending tasks** — a plan with Task 1 (ticked, missing file) and Task 2 (ticked, no Files block) produced `rc=4` and exactly two `plan-checkoff: verify: …` lines on stderr, one per task, confirming the process-substitution loop does not lose `rc` and that per-task reporting doesn't short-circuit.
- **(f) shellcheck / lint-shell** — clean, see Spec compliance table.
- **(g) commit** — subject exact, no stray trailers.

All of the above matched the brief's intended behavior exactly. The implementation itself is correct, minimal, and consistent with the established style (`say`, `VERDICT` matching, quoting conventions from Task 3).

### Important — Step 2 verification claim in the report does not match reality

- **Where:** `task-4-report.md` lines 30-32 ("Before Implementation (Step 2)" section): "Test 34: **[PASS]** (vacuously passes - no ticked boxes)".
- **Evidence:** I reproduced the brief's Step 2 exactly — extracted the parent commit `0619198` (`git archive 0619198`) into a scratch dir, overlaid the current (HEAD) test file containing tests 31-34, and ran the suite against the *old* `plan-checkoff` (no `--verify` support). Result: **all five new assertions fail**, including the one backing test 34 ("--verify ignores tasks with no ticked box"), each with `rc=2` (usage error) — not `rc=0` as the test's own condition (`if [ "$rc" = "0" ]`) requires for a pass. The parent script's `case "${1:-}" in … -*) usage ;; esac` matches `--verify` unconditionally via the `-*` fallthrough and calls `usage` (exit 2) before ever inspecting the plan, so there is no code path by which test 34 could pass at that commit regardless of ticked-box content.
- **Impact:** This is the brief's own Step 2 prediction (task-4-brief.md line 52: "test 34 passes vacuously and is a regression guard"), which is itself incorrect, and the report repeats it as an observed, verified fact rather than flagging the discrepancy. It does not affect the shipped behavior — HEAD f35c130 passes all 45 tests correctly, and the final `--verify` implementation is behaviorally correct in every probe above — but the report's "Self-Review Against Brief" line "Step 2: Tests 31-33 fail with rc=2; test 34 passes vacuously" overstates what was actually verified, and Rule 13 ("fail loud", never silently paper over an unexpected result) argues this discrepancy should have been surfaced rather than echoed as confirmation.
- **Fix:** No code change needed. The report should be corrected to state that all five assertions (not four) failed with rc=2 at the pre-implementation checkpoint, and should note that the brief's Step 2 expectation for test 34 was itself inaccurate (the `--verify` flag is rejected by argument parsing before task content is ever inspected, so no ticked-box content can make the old binary exit 0 for a `--verify` invocation).

No other quality issues found. This finding does not block approval of the code itself, which is correct, minimal, in-style, and fully tested; it is a documentation/reporting accuracy issue in `task-4-report.md`.

## Cannot verify from diff

- Whether the implementer actually ran Step 2 against the pre-implementation script and misread the result, or never ran it and simply copied the brief's (incorrect) prediction verbatim into the report, cannot be determined from the diff or the report text — both produce the same wording. What can be shown, and was shown above, is that the claimed result ("test 34 passes vacuously") is false for any invocation of the parent-commit binary, regardless of how the report's line came to be written.
