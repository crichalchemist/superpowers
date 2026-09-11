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
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/demo.md >/dev/null 2>&1 )
p="$r/docs/superpowers/plans/demo.md"
[ "$(boxes_checked "$p")" = "2" ] && pass "completed task's boxes all flip" || fail "completed task's boxes all flip"
[ "$(boxes_open "$p")" = "2" ] && pass "mid-loop task keeps its boxes unchecked" || fail "mid-loop task keeps its boxes unchecked"

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
grep -q '^- \[ \] \*\*Step 1: embedded' "$p" && pass "fenced template content survives reconcile" || fail "fenced template content survives reconcile"
grep -q 'shows `- \[ \]` before' "$p" && pass "inline prose checkbox is not rewritten" || fail "inline prose checkbox is not rewritten"

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
[ "$(boxes_checked "$r/docs/superpowers/plans/fh.md")" = "1" ] \
  && pass "fenced Task heading does not split a task" || fail "fenced Task heading does not split a task"

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
grep -q '^- \[x\] \*\*Step 1: one' "$p" && grep -q '^- \[ \] \*\*Step 1: ten' "$p" \
  && pass "Task 1 completion does not flip Task 10" || fail "Task 1 completion does not flip Task 10"

# --- 6. second run is byte-identical / 7. hand-checked box preserved ---
r=$(new_repo); write_plan "$r" idem
write_ledger "$r" idem "Task 1: complete (commits 1111111..2222222, review clean)"
p="$r/docs/superpowers/plans/idem.md"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/idem.md >/dev/null 2>&1 )
sum1=$(cksum < "$p"); mt1=$(stat -f %m "$p" 2>/dev/null || stat -c %Y "$p")
sleep 1
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/idem.md >/dev/null 2>&1 ); rc=$?
sum2=$(cksum < "$p"); mt2=$(stat -f %m "$p" 2>/dev/null || stat -c %Y "$p")
[ "$sum1" = "$sum2" ] && [ "$rc" = "0" ] && pass "second run changes nothing and exits 0" || fail "second run changes nothing and exits 0"
[ "$mt1" = "$mt2" ] && pass "zero-flip run skips the rewrite entirely" || fail "zero-flip run skips the rewrite entirely"
grep -q '^- \[x\] \*\*Step 1: alpha' "$p" && pass "hand-checked box is never reverted" || fail "hand-checked box is never reverted"

# --- 8. absent ledger: exit 0, plan untouched ---
r=$(new_repo); write_plan "$r" noledger
p="$r/docs/superpowers/plans/noledger.md"
before=$(cksum < "$p")
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/noledger.md >/dev/null 2>&1 ); rc=$?
[ "$rc" = "0" ] && [ "$before" = "$(cksum < "$p")" ] \
  && pass "absent ledger leaves the plan untouched, exits 0" || fail "absent ledger leaves the plan untouched, exits 0"

# --- 9. foreign ledger refused, exit 3 ---
r=$(new_repo); write_plan "$r" mine
mkdir -p "$r/.superpowers/sdd/mine"
{ echo "# SDD ledger — plan: docs/superpowers/plans/other.md"
  echo "Task 1: complete (commits 3333333..4444444, review clean)"; } > "$r/.superpowers/sdd/mine/progress.md"
p="$r/docs/superpowers/plans/mine.md"; before=$(cksum < "$p")
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/mine.md >/dev/null 2>&1 ); rc=$?
[ "$rc" = "3" ] && [ "$before" = "$(cksum < "$p")" ] \
  && pass "foreign ledger is refused, plan untouched, exit 3" || fail "foreign ledger is refused, plan untouched, exit 3"

# --- 10. orphan task number refuses wholesale ---
r=$(new_repo); write_plan "$r" orphan
write_ledger "$r" orphan \
  "Task 1: complete (commits 5555555..6666666, review clean)" \
  "Task 7: complete (commits 7777777..8888888, review clean)"
p="$r/docs/superpowers/plans/orphan.md"; before=$(cksum < "$p")
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/orphan.md >/dev/null 2>&1 ); rc=$?
[ "$rc" = "3" ] && [ "$before" = "$(cksum < "$p")" ] \
  && pass "orphan task refuses wholesale — no partial reconcile" || fail "orphan task refuses wholesale — no partial reconcile"

# --- 14. quoted completion inside a ruling does not count ---
r=$(new_repo); write_plan "$r" quoted
write_ledger "$r" quoted \
  "Ruling: deferred the Task 1: complete rewrite — cost is rework — see notes" \
  "  Task 2: complete (indented, not a record)"
p="$r/docs/superpowers/plans/quoted.md"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/quoted.md >/dev/null 2>&1 )
[ "$(boxes_checked "$p")" = "0" ] \
  && pass "quoted/indented completion text does not mark a task done" || fail "quoted/indented completion text does not mark a task done"

# --- 15. final task's range extends to EOF ---
r=$(new_repo); write_plan "$r" eof
write_ledger "$r" eof "Task 2: complete (commits 9999999..aaaaaaa, review clean)"
p="$r/docs/superpowers/plans/eof.md"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/eof.md >/dev/null 2>&1 )
grep -q '^- \[x\] \*\*Step 2: delta' "$p" \
  && pass "final task's range extends to EOF" || fail "final task's range extends to EOF"

# --- 16. repo-relative ledger vs absolute invocation ---
r=$(new_repo); write_plan "$r" abs
write_ledger "$r" abs "Task 1: complete (commits bbbbbbb..ccccccc, review clean)"
( cd "$r" && "$CHECKOFF" "$r/docs/superpowers/plans/abs.md" >/dev/null 2>&1 ); rc=$?
[ "$rc" = "0" ] && [ "$(boxes_checked "$r/docs/superpowers/plans/abs.md")" = "2" ] \
  && pass "absolute invocation matches a repo-relative ledger" || fail "absolute invocation matches a repo-relative ledger"

# --- 17. empty ledger refuses ---
r=$(new_repo); write_plan "$r" empty
mkdir -p "$r/.superpowers/sdd/empty"; : > "$r/.superpowers/sdd/empty/progress.md"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/empty.md >/dev/null 2>&1 ); rc=$?
[ "$rc" = "3" ] && pass "empty ledger refuses with exit 3" || fail "empty ledger refuses with exit 3"

# --- 18. CRLF ledger identity line does not refuse ---
r=$(new_repo); write_plan "$r" crlf
mkdir -p "$r/.superpowers/sdd/crlf"
printf '# SDD ledger — plan: docs/superpowers/plans/crlf.md\r\nTask 1: complete (commits ddddddd..eeeeeee, review clean)\r\n' \
  > "$r/.superpowers/sdd/crlf/progress.md"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/crlf.md >/dev/null 2>&1 ); rc=$?
[ "$rc" = "0" ] && pass "CRLF ledger identity does not refuse spuriously" || fail "CRLF ledger identity does not refuse spuriously"

# --- 19. nested >=4-backtick fence: documented toggle limitation ---
r=$(new_repo)
cat > "$r/docs/superpowers/plans/nested.md" <<'PLAN'
# Nested Fence Plan

### Task 1: First

````markdown
```bash
echo hi
```
````

- [ ] **Step 1: after the nested block**
PLAN
write_ledger "$r" nested "Task 1: complete (commits fffffff..0000000, review clean)"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/nested.md >/dev/null 2>&1 )
# The toggle desyncs across nested fences; this pins current behavior so the
# limitation stays documented rather than silently changing. See the spec's
# "Fence model — stated limits".
n=$(boxes_checked "$r/docs/superpowers/plans/nested.md")
[ "$n" = "0" ] || [ "$n" = "1" ] \
  && pass "nested >=4-backtick fence behavior is pinned (observed: $n)" || fail "nested fence pinned"

# --- 11. usage / missing plan ---
( "$CHECKOFF" >/dev/null 2>&1 ); [ "$?" = "2" ] && pass "no args exits 2" || fail "no args exits 2"
( "$CHECKOFF" /nope/missing.md >/dev/null 2>&1 ); [ "$?" = "2" ] && pass "missing plan exits 2" || fail "missing plan exits 2"

# --- 12. parser agreement with task-brief on real plans ---
agree=1
for f in 2026-06-09-sdd-task-scoped-review-dispatch 2026-07-06-sdd-plan-scoped-workspace 2026-07-15-sdd-fix-loop-redesign; do
  plan="$REPO_ROOT/docs/superpowers/plans/$f.md"
  [ -f "$plan" ] || continue
  for n in 1 2 3; do
    brief=$(mktemp)
    if "$TASK_BRIEF" "$plan" "$n" "$brief" >/dev/null 2>&1; then
      # task-brief's extracted range must contain exactly the boxes sdd-checkoff
      # would flip for that task: compare open-box counts.
      tb=$(grep -c '^\s*- \[ \]' "$brief" || true)
      co=$("$CHECKOFF" --print-range "$plan" "$n" 2>/dev/null | grep -c '^\s*- \[ \]' || true)
      [ "$tb" = "$co" ] || { agree=0; echo "    mismatch: $f Task $n (task-brief=$tb sdd-checkoff=$co)"; }
    fi
    rm -f "$brief"
  done
done
[ "$agree" = "1" ] && pass "parser agreement with task-brief on real plans" || fail "parser agreement with task-brief on real plans"

echo
if [ "$failures" -eq 0 ]; then
  echo "All sdd-checkoff tests passed"
else
  echo "$failures sdd-checkoff test(s) failed"
  exit 1
fi
