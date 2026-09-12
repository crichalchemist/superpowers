# Task 2: active-plan marker script — Report

## Step execution

### Step 1: Write the failing tests
Created `tests/claude-code/test-active-plan.sh` with all 9 test assertions exactly as specified in the brief.

### Step 2: Run tests red
**Last line of red run:**
```
8 active-plan test(s) failed
```
(9 assertions, 1 passed vacuously because it doesn't invoke the script; 8 failed as expected since the script doesn't exist)

### Step 3: Write the script
Created `skills/subagent-driven-development/scripts/active-plan` with all functionality:
- `set PLAN_FILE`: writes absolute path to `.superpowers/sdd/active-plan`, prints it, exit 0
- `clear`: removes marker idempotently, exit 0 always
- `show`: prints marker, exit 1 if absent
- Marker is git-ignored via `.superpowers/sdd/.gitignore`
- Resolves repository root from plan location, not caller location
- Exit 2 for usage errors, missing plans, or non-git directories

Chmod +x applied.

### Step 4: Run tests green
**Full green output:**
```
active-plan tests
  [PASS] set writes the absolute plan path to the marker
  [PASS] set prints the absolute plan path
  [PASS] set resolves the root from the plan, not the caller
  [PASS] set on a missing plan exits 2 and writes nothing
  [PASS] show exits 1 with no marker
  [PASS] show prints the marker once set
  [PASS] clear removes the marker and is idempotent
  [PASS] marker is git-ignored
  [PASS] no arguments is a usage error, exit 2

All active-plan tests passed
```

### Step 5: Lint
**Shellcheck output:**
```
(no output — both files are clean)
```

Command: `shellcheck --severity=warning skills/subagent-driven-development/scripts/active-plan tests/claude-code/test-active-plan.sh`

### Step 6: Wire the test runner
Added `"test-active-plan.sh"` entry to the `tests=()` array in `tests/claude-code/run-skill-tests.sh` immediately after `"test-plan-checkoff.sh"` (line 80, consistent with controller's line adjustment guidance).

### Step 7: Commit
**Commit hash:** `6ffaa17`
**Subject:** `feat(sdd): active-plan marker names the plan a session is executing`
**Files committed:** 
- `skills/subagent-driven-development/scripts/active-plan` (created)
- `tests/claude-code/test-active-plan.sh` (created)
- `tests/claude-code/run-skill-tests.sh` (modified)

No trailers. Plain conventional commit message per controller override.

## Verification

- **All 9 test assertions:** PASS
- **Shellcheck clean:** Both files free of warnings/errors
- **No dependencies:** Script uses only bash built-ins and git
- **No host environment pollution:** Tests create throwaway git repos in `/tmp`
- **Commit clean:** Only the three specified files touched

## Concerns

None. The implementation is complete and verified at each step per the brief's TDD order.
