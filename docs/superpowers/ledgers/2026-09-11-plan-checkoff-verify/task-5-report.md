# Task 5: Wire the skills — Report

## Step 1: Anchor Check

Command:
```bash
grep -n 'scripts/plan-checkoff PLAN_FILE. one last' skills/subagent-driven-development/SKILL.md
grep -n '^4. Mark as completed$\|^### Step 3: Complete Development$' skills/executing-plans/SKILL.md
```

Output:
```
skills/subagent-driven-development/SKILL.md:486:Before deleting the workspace, run `scripts/plan-checkoff PLAN_FILE` one last
skills/executing-plans/SKILL.md:31:4. Mark as completed
skills/executing-plans/SKILL.md:33:### Step 3: Complete Development
```

**Result:** All three anchors confirmed at expected lines.

---

## Step 2: Extend the SDD teardown paragraph

**File:** `skills/subagent-driven-development/SKILL.md:486-493`

**Anchor:** The paragraph beginning "Before deleting the workspace, run `scripts/plan-checkoff PLAN_FILE` one last"

**Text inserted after final sentence (after line 493):**
```
An exit of 4 means a ledgered task's `Files:` block names a path that does
not exist, or lists no files at all — either the task is not done or the plan
is wrong about it; resolve that before deleting the workspace, then rerun.
```

---

## Step 3: Wire executing-plans step 2.4 and step 3

### Edit 1: Replace line 31

**File:** `skills/executing-plans/SKILL.md:31`

**Original:**
```
4. Mark as completed
```

**Replaced with:**
```
4. Mark as completed — the todo, and the plan file: run
   `../subagent-driven-development/scripts/plan-checkoff --done N PLAN_FILE`
   (path relative to this skill's directory) for the task you just finished.
   Exit 4 means a path the task's `Files:` block names does not exist yet, or
   the task lists none: the task is not done — fix what is missing, then rerun.
```

### Edit 2: Insert bullet under Step 3

**File:** `skills/executing-plans/SKILL.md:39-42`

**Anchor:** The section "### Step 3: Complete Development" with "After all tasks complete and verified:"

**Text inserted as first bullet:**
```
- Run `../subagent-driven-development/scripts/plan-checkoff --verify PLAN_FILE`;
  a non-zero exit lists ticked tasks whose deliverables are missing — resolve
  them before going on.
```

---

## Step 4: Prove the edits are the only changes

### Check 1: git diff --stat

```
skills/executing-plans/SKILL.md             | 9 ++++++++-
 skills/subagent-driven-development/SKILL.md | 3 +++
 2 files changed, 11 insertions(+), 1 deletion(-)
```

**Result:** ✓ Exactly two files, with expected line counts (+9 -1 and +3 -0).

### Check 2: Red flags / rationalizations / "human partner"

Command:
```bash
git diff -- skills/ | grep -c -i -E 'red flag|rationaliz|human partner'
```

Output:
```
0
```

**Result:** ✓ No forbidden phrases modified.

---

## Step 5: Test Runs

### Test 1: plan-checkoff skill test

Command:
```bash
bash tests/claude-code/test-plan-checkoff.sh
```

Result summary:
- **[PASS] count:** 45
- **Final status:** All plan-checkoff tests passed

### Test 2: supercritic test suite

Command:
```bash
bash tests/supercritic/run-tests.sh
```

Result summary:
- **Final status:** === All supercritic tests passed ===

---

## Step 6: Commit

Command:
```bash
git add skills/subagent-driven-development/SKILL.md skills/executing-plans/SKILL.md
git commit -m "feat(skills): executing-plans and SDD call plan-checkoff with verification"
```

**Commit hash:** `61d642105e18a16f6f2a407232631b20dca2a2b5`

**Commit subject:** `feat(skills): executing-plans and SDD call plan-checkoff with verification`

---

## Self-Review Against Spec

✓ **Task interface:** Both --done N PLAN_FILE and --verify PLAN_FILE interfaces wired into skill call sites

✓ **Exact text:** All three text insertions match the brief exactly, character-for-character

✓ **Scope:** Only the two named files modified; no other files touched

✓ **Content integrity:** No red flags, rationalizations, or "human partner" phrases changed

✓ **Tests:** 45 plan-checkoff tests pass; all supercritic tests pass; tree remains green

✓ **Anchors:** All three anchors confirmed at expected lines before edits

✓ **Commit:** Exactly one commit, with brief-specified subject, no agent trailers

✓ **Relative path:** executing-plans SKILL.md correctly uses `../subagent-driven-development/scripts/plan-checkoff` (path relative to skill's directory)

✓ **Ordering:** --verify inserted as first bullet under Step 3, immediately after "After all tasks complete and verified:"

✓ **Exit code documentation:** Both call sites document exit 4 semantics as specified in Global Constraints

---

## Concerns

None. All steps completed as specified. No deviations from the brief.
