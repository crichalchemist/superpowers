# Task 1 Review: Rename sdd-checkoff to plan-checkoff

**Verdict: Spec compliance MET. Task quality: Approved.**

## Spec compliance

| Requirement (brief) | Status | Evidence |
|---|---|---|
| `git mv` scripts/sdd-checkoff → scripts/plan-checkoff | Met | `git log --follow` on the new path resolves through 33f9cab into the file's pre-rename commit history (f0de527, 33272a8, f02b6c8, 86ade8f) — proves a real rename, not delete+add. |
| `git mv` tests/claude-code/test-sdd-checkoff.sh → test-plan-checkoff.sh | Met | Same commit's diffstat lists `tests/claude-code/test-plan-checkoff.sh \| 14 +++++++-------` as a modified (not added) path; combined with the script's follow result, both renames are via `git mv`. |
| Script: usage comment (header) updated | Met | diff hunk: `-# Usage: sdd-checkoff PLAN_FILE` / `+# Usage: plan-checkoff PLAN_FILE` and the `--print-range` line. |
| Script: `die()` prefix updated | Met | diff: `-die() { echo "sdd-checkoff: $*" >&2; exit 3; }` → `+die() { echo "plan-checkoff: $*" ...`. |
| Script: two `usage:` strings updated | Met | diff: `--print-range` usage string and the main `[ $# -eq 1 ]` usage string both changed. |
| Script: two `mktemp` templates updated | Met | diff: `.sdd-checkoff.XXXXXX` → `.plan-checkoff.XXXXXX` and `.sdd-checkoff-count.XXXXXX` → `.plan-checkoff-count.XXXXXX`. |
| Test file: line 2 comment | Met | diff: `-# Tests for sdd-checkoff:` → `+# Tests for plan-checkoff:`. |
| Test file: `CHECKOFF="$SCRIPT_DIR/plan-checkoff"` | Met | diff: `-CHECKOFF="$SCRIPT_DIR/sdd-checkoff"` → `+CHECKOFF="$SCRIPT_DIR/plan-checkoff"`. |
| Test file: `echo "plan-checkoff tests"` | Met | diff: `-echo "sdd-checkoff tests"` → `+echo "plan-checkoff tests"`. |
| Test file: leak-test glob `.plan-checkoff*` | Met | diff: `-name '.sdd-checkoff*'` → `-name '.plan-checkoff*'`. |
| Test file: two summary strings | Met | diff: `All sdd-checkoff tests passed` → `All plan-checkoff tests passed`; `$failures sdd-checkoff test(s) failed` → `$failures plan-checkoff test(s) failed`. |
| `run-skill-tests.sh` array entry | Met | diff: `-"test-sdd-checkoff.sh"` → `+"test-plan-checkoff.sh"`. |
| SKILL.md line 149 | Met | diff: `-scripts/sdd-checkoff PLAN_FILE` → `+scripts/plan-checkoff PLAN_FILE` in the setup bullet; surrounding text (ledger/reconcile prose) unchanged in the same hunk. |
| SKILL.md line 486 | Met | diff: same substitution in the teardown paragraph opening "Before deleting the workspace, run..."; rest of paragraph byte-identical. |
| `.claude/CLAUDE.md` mention | Met | diff: `- **SDD runs.** At teardown, after \`scripts/sdd-checkoff PLAN_FILE\`` → `plan-checkoff`; rest of the bullet unchanged. |
| `git grep -n 'sdd-checkoff' ...` prints nothing | Met | Ran independently in the worktree at HEAD 33f9cab: exit code 1 (no matches), no stdout. |
| `bash tests/claude-code/test-plan-checkoff.sh` → 23 PASS, "All plan-checkoff tests passed" | Met | Ran independently: all 23 `[PASS]` lines present, exit 0, final line `All plan-checkoff tests passed`. |
| `shellcheck --severity=warning` on both files → no output | Met | Ran independently: exit 0, no output. |
| Commit subject `refactor(sdd): rename sdd-checkoff to plan-checkoff` | Met | `git log -1 --format='%B' 33f9cab` → subject matches exactly, no body, no trailer. |

Nothing outside the brief's scope was touched: the diffstat lists exactly the 5 files named in the brief's Files section, 19 insertions / 19 deletions — consistent with a pure string-substitution rename (no line adds/removes beyond the touched lines).

## Task quality: Approved

No findings. Specifically checked and clean:

- **Behaviour change hidden in the rename**: none. Every diff hunk in the script is a substring substitution on an existing line (usage text, die-prefix, mktemp templates); the fence-toggle line `/^```/ { infence = !infence }` and all control flow are untouched (visible as unchanged context in the diff).
- **Missed reference**: none — `git grep -n 'sdd-checkoff' -- . ':!docs/superpowers/ledgers' ':!docs/superpowers/plans' ':!docs/superpowers/specs'` was re-run independently against the worktree HEAD and returned no matches. The report's claim of "8 references" in the script and "7" in the test file undercounts slightly (test file diff actually shows 7 hunks including the un-brief-mandated `# agrees instead: run sdd-checkoff for real...` comment on line ~277, correctly caught anyway), but the exhaustive grep is what matters and it is clean.
- **Commit trailers**: none present (`git log -1 --format='%B'` shows only the subject line, no `Co-Authored-By` or agent trailer).
- **Style drift**: none — `set -euo pipefail` / `set -uo pipefail` preserved as-is in both files, no new `shellcheck disable` directives added, quoting untouched, house test idiom (`if …; then pass …; else fail …; fi`) untouched.
- **History preserved**: `git log --follow` on the new script path resolves through the prior commits (f0de527, 33272a8, f02b6c8, 86ade8f), confirming `git mv` was used rather than delete+recreate.
- **Test count**: 23 assertions before and after, all passing — matches the brief's "23 assertions must pass unchanged" requirement.

## Cannot verify from diff

None — all brief requirements were independently confirmed either from the diff content or by re-running the specified commands (`git grep`, the test suite, `shellcheck`, `git log --follow`) directly against the worktree at HEAD 33f9cab.
