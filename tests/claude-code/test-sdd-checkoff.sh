#!/usr/bin/env bash
# Tests for sdd-checkoff: ledger -> plan checkbox reconciliation.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/../../skills/subagent-driven-development/scripts" && pwd)"
CHECKOFF="$SCRIPT_DIR/sdd-checkoff"
TASK_BRIEF="$SCRIPT_DIR/task-brief"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

failures=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }

echo "sdd-checkoff tests"

# Each test builds a throwaway git repo so sdd-workspace's `git rev-parse` works.
new_repo() {
  local d; d=$(mktemp -d)
  git -C "$d" init -q
  mkdir -p "$d/docs/superpowers/plans"
  echo "$d"
}

# write_plan REPO NAME -- writes a two-task plan, 2 boxes each.
write_plan() {
  cat > "$1/docs/superpowers/plans/$2.md" <<'PLAN'
# Demo Plan

### Task 1: First

- [ ] **Step 1: alpha**
- [ ] **Step 2: beta**

### Task 2: Second

- [ ] **Step 1: gamma**
- [ ] **Step 2: delta**
PLAN
}

# write_ledger REPO SLUG LINES...
write_ledger() {
  local repo=$1 slug=$2; shift 2
  local dir="$repo/.superpowers/sdd/$slug"
  mkdir -p "$dir"
  { echo "# SDD ledger — plan: docs/superpowers/plans/$slug.md"; printf '%s\n' "$@"; } > "$dir/progress.md"
}

boxes_checked() { grep -c '^\s*- \[x\]' "$1" || true; }
boxes_open()    { grep -c '^\s*- \[ \]' "$1" || true; }

# --- 1. completed task's boxes all flip / 2. incomplete task untouched ---
r=$(new_repo); write_plan "$r" demo
write_ledger "$r" demo "Task 1: complete (commits abc1234..def5678, review clean)"
p="$r/docs/superpowers/plans/demo.md"
mode_before=$(stat -f %Lp "$p" 2>/dev/null || stat -c %a "$p")
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/demo.md >/dev/null 2>&1 )
if [ "$(boxes_checked "$p")" = "2" ]; then pass "completed task's boxes all flip"; else fail "completed task's boxes all flip"; fi
if [ "$(boxes_open "$p")" = "2" ]; then pass "mid-loop task keeps its boxes unchecked"; else fail "mid-loop task keeps its boxes unchecked"; fi
mode_after=$(stat -f %Lp "$p" 2>/dev/null || stat -c %a "$p")
if [ "$mode_before" = "$mode_after" ]; then pass "plan file mode is preserved across a flip"; else fail "plan file mode is preserved across a flip (before=$mode_before after=$mode_after)"; fi

# --- 3. fenced checkbox survives / 13. inline prose checkbox survives ---
r=$(new_repo)
cat > "$r/docs/superpowers/plans/fence.md" <<'PLAN'
# Fence Plan

### Task 1: First

- [ ] **Step 1: real**

The template shows `- [ ]` before each step.

```markdown
- [ ] **Step 1: embedded, must not flip**
```
PLAN
write_ledger "$r" fence "Task 1: complete (commits aaa1111..bbb2222, review clean)"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/fence.md >/dev/null 2>&1 )
p="$r/docs/superpowers/plans/fence.md"
if grep -q '^- \[ \] \*\*Step 1: embedded' "$p"; then pass "fenced template content survives reconcile"; else fail "fenced template content survives reconcile"; fi
if grep -q "shows \`- \[ \]\` before" "$p"; then pass "inline prose checkbox is not rewritten"; else fail "inline prose checkbox is not rewritten"; fi

# --- 4. fenced Task heading does not split a task ---
r=$(new_repo)
cat > "$r/docs/superpowers/plans/fh.md" <<'PLAN'
# Fenced Heading Plan

### Task 1: First

```markdown
### Task 2: not a real boundary
```

- [ ] **Step 1: still inside Task 1**
PLAN
write_ledger "$r" fh "Task 1: complete (commits ccc3333..ddd4444, review clean)"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/fh.md >/dev/null 2>&1 )
if [ "$(boxes_checked "$r/docs/superpowers/plans/fh.md")" = "1" ]; then pass "fenced Task heading does not split a task"; else fail "fenced Task heading does not split a task"; fi

# --- 5. Task 1 does not flip Task 10 ---
r=$(new_repo)
cat > "$r/docs/superpowers/plans/ten.md" <<'PLAN'
# Ten Plan

### Task 1: First

- [ ] **Step 1: one**

### Task 10: Tenth

- [ ] **Step 1: ten**
PLAN
write_ledger "$r" ten "Task 1: complete (commits eee5555..fff6666, review clean)"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/ten.md >/dev/null 2>&1 )
p="$r/docs/superpowers/plans/ten.md"
if grep -q '^- \[x\] \*\*Step 1: one' "$p" && grep -q '^- \[ \] \*\*Step 1: ten' "$p"; then pass "Task 1 completion does not flip Task 10"; else fail "Task 1 completion does not flip Task 10"; fi

# --- 6. second run is byte-identical / 7. hand-checked box preserved ---
r=$(new_repo); write_plan "$r" idem
write_ledger "$r" idem "Task 1: complete (commits 1111111..2222222, review clean)"
p="$r/docs/superpowers/plans/idem.md"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/idem.md >/dev/null 2>&1 )
sum1=$(cksum < "$p"); mt1=$(stat -f %m "$p" 2>/dev/null || stat -c %Y "$p")
sleep 1
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/idem.md >/dev/null 2>&1 ); rc=$?
sum2=$(cksum < "$p"); mt2=$(stat -f %m "$p" 2>/dev/null || stat -c %Y "$p")
if [ "$sum1" = "$sum2" ] && [ "$rc" = "0" ]; then pass "second run changes nothing and exits 0"; else fail "second run changes nothing and exits 0"; fi
if [ "$mt1" = "$mt2" ]; then pass "zero-flip run skips the rewrite entirely"; else fail "zero-flip run skips the rewrite entirely"; fi
if grep -q '^- \[x\] \*\*Step 1: alpha' "$p"; then pass "hand-checked box is never reverted"; else fail "hand-checked box is never reverted"; fi

# --- 8. absent ledger: exit 0, plan untouched ---
r=$(new_repo); write_plan "$r" noledger
p="$r/docs/superpowers/plans/noledger.md"
before=$(cksum < "$p")
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/noledger.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "0" ] && [ "$before" = "$(cksum < "$p")" ]; then pass "absent ledger leaves the plan untouched, exits 0"; else fail "absent ledger leaves the plan untouched, exits 0"; fi

# --- countfile does not leak on a flipping run ---
r=$(new_repo); write_plan "$r" leak
write_ledger "$r" leak "Task 1: complete (commits 1111111..2222222, review clean)"
sysTmp=$(dirname "$(mktemp -u)")
marker=$(mktemp)
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/leak.md >/dev/null 2>&1 )
# -newer marker (created immediately before the run) rather than a before/after
# directory diff, so unrelated tmp.* churn elsewhere in the shared system temp
# dir can't produce a false failure.
new_tmp=$(find "$sysTmp" -maxdepth 1 -name 'tmp.*' -type f -newer "$marker" 2>/dev/null | grep -vF "$marker" | sort)
rm -f "$marker"
if [ -z "$new_tmp" ]; then pass "countfile does not leak on a flipping run"; else fail "countfile leaks on a flipping run: $new_tmp"; fi

# --- 9. foreign ledger refused, exit 3 ---
r=$(new_repo); write_plan "$r" mine
mkdir -p "$r/.superpowers/sdd/mine"
{ echo "# SDD ledger — plan: docs/superpowers/plans/other.md"
  echo "Task 1: complete (commits 3333333..4444444, review clean)"; } > "$r/.superpowers/sdd/mine/progress.md"
p="$r/docs/superpowers/plans/mine.md"; before=$(cksum < "$p")
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/mine.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "3" ] && [ "$before" = "$(cksum < "$p")" ]; then pass "foreign ledger is refused, plan untouched, exit 3"; else fail "foreign ledger is refused, plan untouched, exit 3"; fi

# --- 10. orphan task number refuses wholesale ---
r=$(new_repo); write_plan "$r" orphan
write_ledger "$r" orphan \
  "Task 1: complete (commits 5555555..6666666, review clean)" \
  "Task 7: complete (commits 7777777..8888888, review clean)"
p="$r/docs/superpowers/plans/orphan.md"; before=$(cksum < "$p")
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/orphan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "3" ] && [ "$before" = "$(cksum < "$p")" ]; then pass "orphan task refuses wholesale — no partial reconcile"; else fail "orphan task refuses wholesale — no partial reconcile"; fi

# --- 14. quoted completion inside a ruling does not count ---
r=$(new_repo); write_plan "$r" quoted
write_ledger "$r" quoted \
  "Ruling: deferred the Task 1: complete rewrite — cost is rework — see notes" \
  "  Task 2: complete (indented, not a record)"
p="$r/docs/superpowers/plans/quoted.md"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/quoted.md >/dev/null 2>&1 )
if [ "$(boxes_checked "$p")" = "0" ]; then pass "quoted/indented completion text does not mark a task done"; else fail "quoted/indented completion text does not mark a task done"; fi

# --- 15. final task's range extends to EOF ---
r=$(new_repo); write_plan "$r" eof
write_ledger "$r" eof "Task 2: complete (commits 9999999..aaaaaaa, review clean)"
p="$r/docs/superpowers/plans/eof.md"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/eof.md >/dev/null 2>&1 )
if grep -q '^- \[x\] \*\*Step 2: delta' "$p"; then pass "final task's range extends to EOF"; else fail "final task's range extends to EOF"; fi

# --- 16. repo-relative ledger vs absolute invocation ---
r=$(new_repo); write_plan "$r" abs
write_ledger "$r" abs "Task 1: complete (commits bbbbbbb..ccccccc, review clean)"
( cd "$r" && "$CHECKOFF" "$r/docs/superpowers/plans/abs.md" >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "0" ] && [ "$(boxes_checked "$r/docs/superpowers/plans/abs.md")" = "2" ]; then pass "absolute invocation matches a repo-relative ledger"; else fail "absolute invocation matches a repo-relative ledger"; fi

# --- 17. empty ledger refuses ---
r=$(new_repo); write_plan "$r" empty
mkdir -p "$r/.superpowers/sdd/empty"; : > "$r/.superpowers/sdd/empty/progress.md"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/empty.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "3" ]; then pass "empty ledger refuses with exit 3"; else fail "empty ledger refuses with exit 3"; fi

# --- 18. CRLF ledger identity line does not refuse ---
r=$(new_repo); write_plan "$r" crlf
mkdir -p "$r/.superpowers/sdd/crlf"
printf '# SDD ledger — plan: docs/superpowers/plans/crlf.md\r\nTask 1: complete (commits ddddddd..eeeeeee, review clean)\r\n' \
  > "$r/.superpowers/sdd/crlf/progress.md"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/crlf.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "0" ]; then pass "CRLF ledger identity does not refuse spuriously"; else fail "CRLF ledger identity does not refuse spuriously"; fi

# --- 19. nested >=4-backtick fence: documented toggle limitation ---
r=$(new_repo)
cat > "$r/docs/superpowers/plans/nested.md" <<'PLAN'
# Nested Fence Plan

### Task 1: First

````markdown
```bash
echo hi
- [ ] **Step 1: inside the inner fence**
```
````

- [ ] **Step 1: after the nested block**
PLAN
write_ledger "$r" nested "Task 1: complete (commits fffffff..0000000, review clean)"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/nested.md >/dev/null 2>&1 )
# The toggle desyncs across nested fences: the inner ```bash line flips
# infence back off, so the box inside the inner fence is (wrongly) treated as
# unfenced and flips along with the box after the block. This pins that
# documented toggle limitation exactly, so a future fence-model change trips
# this test instead of silently changing behavior. See the spec's "Fence
# model — stated limits".
n=$(boxes_checked "$r/docs/superpowers/plans/nested.md")
if [ "$n" = "2" ]; then pass "nested >=4-backtick fence behavior is pinned (observed: $n)"; else fail "nested fence pinned (expected 2, observed: $n)"; fi

# --- 11. usage / missing plan ---
( "$CHECKOFF" >/dev/null 2>&1 ); if [ "$?" = "2" ]; then pass "no args exits 2"; else fail "no args exits 2"; fi
( "$CHECKOFF" /nope/missing.md >/dev/null 2>&1 ); if [ "$?" = "2" ]; then pass "missing plan exits 2"; else fail "missing plan exits 2"; fi

# --- 12. parser agreement with task-brief on real plans ---
# --print-range is a verbatim copy of task-brief's awk, so comparing against
# it only proves that copy agrees with itself. Prove the main flipping pass
# agrees instead: run sdd-checkoff for real on a scratch copy of each plan
# and compare the boxes it actually flipped against task-brief's extracted
# range for that task. None of these three plans have any pre-existing
# `- [x]` box (verified separately), so every `- [x]` line found in the
# scratch copy after the run is one this run flipped. (Also depends on none
# of the plans having a checkbox inside a re-entrant same-numbered heading
# outside the real task range, e.g. an embedded fixture doc — verified true
# for tasks 1-3 today; a plan edit adding one would need this test revisited.)
agree=1
for f in 2026-06-09-sdd-task-scoped-review-dispatch 2026-07-06-sdd-plan-scoped-workspace 2026-07-15-sdd-fix-loop-redesign; do
  plan="$REPO_ROOT/docs/superpowers/plans/$f.md"
  [ -f "$plan" ] || continue
  for n in 1 2 3; do
    brief=$(mktemp)
    if "$TASK_BRIEF" "$plan" "$n" "$brief" >/dev/null 2>&1; then
      r=$(new_repo)
      cp "$plan" "$r/docs/superpowers/plans/$f.md"
      write_ledger "$r" "$f" "Task $n: complete (commits 0000000..1111111, review clean)"
      copy="$r/docs/superpowers/plans/$f.md"
      ( cd "$r" && "$CHECKOFF" "docs/superpowers/plans/$f.md" >/dev/null 2>&1 )
      flipped=$(grep '^\s*- \[x\]' "$copy" | sed 's/^\([[:space:]]*\)- \[x\]/\1- [ ]/' | sort)
      expected=$(grep '^\s*- \[ \]' "$brief" | sort)
      if ! diff <(printf '%s\n' "$flipped") <(printf '%s\n' "$expected") >/dev/null; then
        agree=0
        echo "    mismatch: $f Task $n"
      fi
    fi
    rm -f "$brief"
  done
done
if [ "$agree" = "1" ]; then pass "parser agreement with task-brief on real plans"; else fail "parser agreement with task-brief on real plans"; fi

echo
if [ "$failures" -eq 0 ]; then
  echo "All sdd-checkoff tests passed"
else
  echo "$failures sdd-checkoff test(s) failed"
  exit 1
fi
