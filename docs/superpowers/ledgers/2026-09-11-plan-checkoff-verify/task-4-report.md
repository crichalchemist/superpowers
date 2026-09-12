# Task 4 Implementation Report

## Summary

Successfully implemented the `--verify` audit mode for plan-checkoff. The mode audits ticked tasks against their Files: blocks without writing anything. Exit codes: 0 for clean, 4 for any ticked task that fails verification.

## Changes Made

### 1. Tests (test-plan-checkoff.sh)
Added four new test sections before "# --- 11. usage / missing plan ---":

- **Test 31**: `--verify` flags a ticked task with missing Create path (rc=4, file unchanged)
- **Test 32**: `--verify` flags a ticked task that lists no files (rc=4)
- **Test 33**: `--verify` on a consistent plan is silent and exits 0
- **Test 34**: `--verify` ignores unticked tasks even if files are missing (rc=0)

### 2. Script (plan-checkoff)
- **Header comment**: Added usage line for `--verify` and extended exit code 4 description
- **usage() function**: Added `echo "       plan-checkoff --verify PLAN_FILE" >&2`
- **Argument case**: Added `--verify) mode="verify"; shift ;;` before `--done)` arm
- **Verify mode block**: Inserted after --done block, before ledger banner:
  - Loops through ticked_tasks using process substitution
  - Calls verify_task for each ticked task
  - Reports failures to stderr with specific format
  - Sets rc=4 if any task fails verification
  - Exits with appropriate code

## Test Results

### Before Implementation (Step 2)
- All five assertions (tests 31-34): **[FAIL]** with rc=2 (usage error, --verify not recognized)
- Note: The brief predicted test 34 would pass vacuously, but it actually fails with rc=2 because argument parsing rejects --verify before any task content is read

### After Implementation (Step 4)
- **45 total tests pass** (40 baseline + 5 new assertions)
- All tests pass including:
  - "--verify flags a ticked task whose path is gone, writes nothing"
  - "--verify names the missing path"
  - "--verify flags a ticked task with no Files lines"
  - "--verify on a consistent plan is silent, exit 0"
  - "--verify ignores tasks with no ticked box"
- No failures

### Linting Results

**shellcheck** (--severity=warning):
```
(no output - clean)
```

**lint-shell.sh**:
```
Linting 2 shell files
(exit 0)
```

## Commit Details

**Hash**: `f35c130`

**Subject**: `feat(sdd): plan-checkoff --verify audits ticked tasks against their Files block`

**Files changed**:
- skills/subagent-driven-development/scripts/plan-checkoff
- tests/claude-code/test-plan-checkoff.sh

**Changes**:
- 52 insertions(+), 1 deletion(-)

## Self-Review Against Brief

✓ Step 1: Four failing tests added before `# --- 11. usage / missing plan ---` section
✓ Step 2: All five assertions fail with rc=2 (brief's prediction of test 34 passing was inaccurate)
✓ Step 3: Mode added with exact code from brief:
  - Header usage line added
  - Exit code 4 line extended to mention --verify failures
  - usage() line added for --verify
  - --verify) arm before --done) arm
  - Verify mode block after --done block, before ledger banner
  - Process substitution loop preserves rc variable
  - Correct VERDICT matching and error messages
✓ Step 4: All tests pass (45 observed)
✓ Step 4: shellcheck clean (no warnings)
✓ Step 4: lint-shell.sh passes (2 files, exit 0)
✓ Step 5: Commit created with exact subject, no agent trailers
✓ Mode value quoted (`mode="verify"`) for consistency with Task 3
✓ VERDICT matching uses quoted comparison (`[ "$mode" = "verify" ]`)
✓ No shellcheck disable directives
✓ No unintended changes outside the scope

## Concerns

None. Implementation is complete and verified.
