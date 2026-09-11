# SDD Plan Check-off Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `sdd-checkoff`, a script that reconciles an implementation plan's checkboxes from its SDD progress ledger, and wire it into SDD setup and teardown.

**Architecture:** A fourth bash sibling in `skills/subagent-driven-development/scripts/`, alongside `sdd-workspace`, `task-brief`, `review-package`. It delegates workspace resolution to `sdd-workspace`, reads `<workspace>/progress.md` for line-anchored `Task <N>: complete` records, and rewrites the plan in a single fence-aware awk pass that flips `- [ ]` to `- [x]` only inside completed tasks' ranges. Two one-line call sites in `SKILL.md` invoke it.

**Tech Stack:** bash, POSIX awk, git. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-09-sdd-checkoff-design.md`

## Global Constraints

- **Fork-local.** Do not target `upstream/dev`. Keep `SKILL.md` edits narrow and away from upstream's active edit regions.
- **Supported plan dialect:** LF line endings, unindented triple-backtick fences. `~~~`, indented, and ≥4-backtick nested fences are out of contract.
- **Fence tracking must be byte-identical to `task-brief` line 29:** `/^```/ { infence = !infence }`. Parity with `task-brief` is the correctness standard.
- **Monotonic:** only `- [ ]` → `- [x]`. Never the reverse, for any reason.
- **Exit codes:** `0` success or nothing to do, `2` usage/missing plan, `3` refusal. Never a non-zero exit for a missing ledger.
- **All-or-nothing:** any refusal leaves the plan byte-identical.
- Scripts are `chmod 755`, `set -euo pipefail`, and pass `shellcheck`.

---

### Task 1: The `sdd-checkoff` script (TDD)

**Files:**
- Create: `skills/subagent-driven-development/scripts/sdd-checkoff`
- Create: `tests/claude-code/test-sdd-checkoff.sh`

**Interfaces:**
- Consumes: `sdd-workspace PLAN_FILE` (sibling script) → prints the plan's absolute workspace directory. Ledger is at `<workspace>/progress.md`.
- Produces: executable `sdd-checkoff PLAN_FILE`. stdout on success: `checked off N task(s), M box(es) in <plan>` where `N` counts tasks with ≥1 box flipped **this run**. Exit 0 / 2 / 3 per Global Constraints. Task 2 wires this exact invocation into `SKILL.md`.

- [x] **Step 1: Write the test file**

Create `tests/claude-code/test-sdd-checkoff.sh` with exactly this content:

```bash
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
```

Note test 12 requires a `--print-range PLAN N` debug mode. That is part of the contract implemented in Step 3.

- [x] **Step 2: Run the test to verify it fails**

Run: `bash tests/claude-code/test-sdd-checkoff.sh`

Expected: fails immediately — `sdd-checkoff` does not exist, so every case reports `[FAIL]` and the script exits 1.

- [x] **Step 3: Write the script**

Create `skills/subagent-driven-development/scripts/sdd-checkoff` with exactly this content:

```bash
#!/usr/bin/env bash
# Reconcile an implementation plan's checkboxes from its SDD progress ledger.
#
# The ledger (.superpowers/sdd/<plan>/progress.md) is authoritative but
# git-ignored and deleted at the end of a run; the plan file is tracked and
# permanent. Without this script the durable record never reflects what
# happened. Run at SDD setup (heals an aborted prior run) and immediately
# before workspace deletion (captures the happy path).
#
# Usage: sdd-checkoff PLAN_FILE
#        sdd-checkoff --print-range PLAN_FILE TASK_NUMBER   # debug/parity
#
# Fence handling is byte-identical to task-brief's toggle. That model does not
# understand ~~~, indented, or >=4-backtick nested fences; see the spec's
# "Fence model — stated limits". Parity with task-brief is the standard.
set -euo pipefail

die() { echo "sdd-checkoff: $*" >&2; exit "${2:-3}"; }

# --print-range prints one task's range, for parity testing against task-brief.
if [ "${1:-}" = "--print-range" ]; then
  [ $# -eq 3 ] || { echo "usage: sdd-checkoff --print-range PLAN_FILE TASK_NUMBER" >&2; exit 2; }
  [ -f "$2" ] || { echo "no such plan file: $2" >&2; exit 2; }
  awk -v n="$3" '
    /^```/ { infence = !infence }
    !infence && /^#+[ \t]+Task[ \t]+[0-9]+/ {
      intask = ($0 ~ ("^#+[ \t]+Task[ \t]+" n "([^0-9]|$)"))
    }
    intask { print }
  ' "$2"
  exit 0
fi

[ $# -eq 1 ] || { echo "usage: sdd-checkoff PLAN_FILE" >&2; exit 2; }
plan=$1
[ -f "$plan" ] || { echo "no such plan file: $plan" >&2; exit 2; }

dir=$("$(cd "$(dirname "$0")" && pwd)/sdd-workspace" "$plan")
ledger="$dir/progress.md"

if [ ! -f "$ledger" ]; then
  echo "sdd-checkoff: no ledger at $ledger — nothing to reconcile" >&2
  exit 0
fi

# Identity. The controller writes "# SDD ledger — plan: <path>" using whatever
# path form it had; we may be invoked with another. Compare by slug, the same
# key sdd-workspace uses for the directory. Strip CR so a CRLF ledger does not
# refuse spuriously.
first=$(head -n 1 "$ledger" | tr -d '\r')
case "$first" in
  '# SDD ledger'*) ;;
  *) die "unrecognized ledger header in $ledger (expected '# SDD ledger — plan: <path>')" ;;
esac
ledger_slug=$(basename "${first##*: }" .md)
plan_slug=$(basename "$plan" .md)
[ "$ledger_slug" = "$plan_slug" ] \
  || die "ledger at $ledger names plan '$ledger_slug', not '$plan_slug' — refusing"

# Completed tasks: line-anchored, so a ruling that quotes "Task 3: complete"
# in prose cannot mark a task done.
completed=$(tr -d '\r' < "$ledger" \
  | awk '/^Task [0-9]+: complete/ { t=$2; sub(/:$/,"",t); print t }' \
  | sort -un | tr '\n' ',' )
completed=${completed%,}

if [ -z "$completed" ]; then
  echo "checked off 0 task(s), 0 box(es) in $plan"
  exit 0
fi

# Every completed task must exist as an unfenced heading, or refuse wholesale.
present=$(awk '
  /^```/ { infence = !infence; next }
  !infence && /^#+[ \t]+Task[ \t]+[0-9]+/ { t=$0; sub(/^#+[ \t]+Task[ \t]+/,"",t); sub(/[^0-9].*$/,"",t); print t }
' "$plan" | sort -un | tr '\n' ',')
missing=""
IFS=, read -r -a want <<< "$completed"
for n in "${want[@]}"; do
  case ",$present" in *",$n,"*) ;; *) missing="$missing $n" ;; esac
done
[ -z "$missing" ] || die "ledger names task(s)$missing with no matching heading in $plan — refusing (plan edited after the run?)"

tmp=$(mktemp "$(dirname "$plan")/.sdd-checkoff.XXXXXX")
countfile=$(mktemp)
trap 'rm -f "$tmp" "$countfile"' EXIT

# Single pass: transformed plan to $tmp, tally to $countfile. Counting inside
# the same pass is what makes "tasks" mean "tasks flipped this run" rather than
# "tasks the ledger lists".
awk -v want="$completed" -v cf="$countfile" '
  BEGIN { n = split(want, a, ","); for (i = 1; i <= n; i++) done[a[i]] = 1 }
  /^```/ { infence = !infence }
  !infence && /^#+[ \t]+Task[ \t]+[0-9]+/ {
    t = $0; sub(/^#+[ \t]+Task[ \t]+/, "", t); sub(/[^0-9].*$/, "", t)
    cur = t; active = (t in done)
  }
  !infence && active && /^[ \t]*- \[ \]/ {
    sub(/- \[ \]/, "- [x]"); boxes++; if (!seen[cur]++) tasks++
  }
  { print }
  END { print tasks + 0 "," boxes + 0 > cf }
' "$plan" > "$tmp"

counts=$(cat "$countfile")
tasks=${counts%,*}
boxes=${counts#*,}

if [ "$boxes" -eq 0 ]; then
  # Skip the mv entirely: replacing the file would change inode and mtime, and
  # awk's print appends a trailing newline to a plan lacking one — a diff from
  # a run that changed nothing.
  echo "checked off 0 task(s), 0 box(es) in $plan"
  exit 0
fi

mv "$tmp" "$plan"
trap - EXIT
echo "checked off $tasks task(s), $boxes box(es) in $plan"
```

- [x] **Step 4: Make it executable**

```bash
chmod 755 skills/subagent-driven-development/scripts/sdd-checkoff
```

- [x] **Step 5: Run the test to verify it passes**

Run: `bash tests/claude-code/test-sdd-checkoff.sh`

Expected: `All sdd-checkoff tests passed`.

If the nested-fence case (test 19) reports a count outside `0` or `1`, do not "fix" the toggle — record the observed value and reconcile it with the spec's stated limits.

- [x] **Step 6: Lint**

```bash
shellcheck skills/subagent-driven-development/scripts/sdd-checkoff tests/claude-code/test-sdd-checkoff.sh
```

Expected: clean. Add narrowly-scoped `# shellcheck disable=` comments only with a reason on the same line.

- [x] **Step 7: Verify no real plan is corrupted**

```bash
git stash list >/dev/null
for f in docs/superpowers/plans/*.md; do
  skills/subagent-driven-development/scripts/sdd-checkoff "$f" || true
done
git diff --stat -- docs/superpowers/plans/
```

Expected: **no diff**. No real plan has a ledger, so every invocation takes the missing-ledger path and exits 0 without writing. A non-empty diff here means the guard failed — stop and fix before committing.

- [x] **Step 8: Commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-checkoff tests/claude-code/test-sdd-checkoff.sh
git commit -m "feat(sdd): sdd-checkoff reconciles plan checkboxes from the ledger"
```

---

### Task 2: Wire the call sites into SKILL.md

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md` (Setup bullet block ~line 141; workspace-deletion node at lines 90, 119–120)

**Interfaces:**
- Consumes: `scripts/sdd-checkoff PLAN_FILE` from Task 1 — exit 0 on a fresh plan, so the setup call is a silent no-op the first time.
- Produces: no code interface. Behavioral change only.

- [x] **Step 1: Add the setup call**

In the Setup section's bullet list, immediately after the bullet describing the ledger identity check (the one ending "leave it in place and start your own, fresh."), add this bullet:

```markdown
- Reconcile the plan's checkboxes from the ledger before dispatching: run this
  skill's `scripts/sdd-checkoff PLAN_FILE`. On a fresh plan it exits 0 and does
  nothing; after an aborted run it checks off the tasks the ledger recorded, so
  the tracked plan file stops lying about what is done.
```

- [x] **Step 2: Add the teardown call**

Find the prose describing the final-review cleanup step that deletes the workspace. Immediately before the deletion instruction, add:

```markdown
Before deleting the workspace, run `scripts/sdd-checkoff PLAN_FILE` one last
time — deletion destroys the ledger, so this is the last moment the plan's
checkboxes can be reconciled from it.
```

- [x] **Step 3: Update the process graph**

In the `digraph` block, replace the node declaration line:

```dot
    "Final review clean: delete this plan's workspace" [shape=box];
```

with:

```dot
    "Final review clean: reconcile plan checkboxes, delete this plan's workspace" [shape=box];
```

Then update both edges that reference the old label (the incoming edge from the final-findings node and the outgoing edge to `"Use superpowers:finishing-a-development-branch"`) to use the new label verbatim. Graphviz creates a new node for any label mismatch, so all three occurrences must match exactly.

- [x] **Step 4: Verify the graph still parses**

```bash
node skills/writing-skills/render-graphs.js skills/subagent-driven-development
```

Expected: `Rendered: subagent_driven_development.svg` with no error. Requires graphviz (`dot`).

Then confirm no orphan node was created:

```bash
grep -c "Final review clean" skills/subagent-driven-development/SKILL.md
```

Expected: `3` (declaration + two edges), all with the new label. Then:

```bash
grep -c "delete this plan's workspace\"" skills/subagent-driven-development/SKILL.md
```

Expected: `0` occurrences of the *old* label as a standalone node string.

- [x] **Step 5: Clean up the render artifact**

```bash
rm -rf skills/subagent-driven-development/diagrams
```

The renderer writes into the skill directory; that output is not committed.

- [x] **Step 6: Run the full SDD test suite**

```bash
bash tests/claude-code/test-sdd-workspace.sh
bash tests/claude-code/test-subagent-driven-development.sh
bash tests/claude-code/test-sdd-checkoff.sh
```

Expected: all pass. `test-subagent-driven-development.sh` asserts against SKILL.md prose, so a failure there means Step 1–3 wording collided with an existing assertion — read the assertion and adjust the added text, not the assertion.

- [x] **Step 7: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md
git commit -m "feat(sdd): reconcile plan checkboxes at setup and before teardown"
```

---

## Self-Review

**Spec coverage:** Interface → Task 1 Step 3. Parsing contract (fence tracking, boundaries, EOF range, anchored flip, duplicate headings) → Task 1 Steps 1, 3. Ledger record matching → Task 1 Step 3, test 14. Guards table, all seven rows → Task 1 tests 8, 9, 10, 17, plus usage cases. Ledger identity by slug + CRLF → Task 1 Step 3, tests 16, 18. Atomicity and skip-mv-on-zero-flips → Task 1 Step 3, test 6. Monotonic → test 7. Fence model limits → test 19. Call sites → Task 2 Steps 1–3. Test plan cases 1–19 → Task 1 Step 1. Out-of-scope items are absent from every task, as intended.

**Placeholder scan:** No TBD/TODO. Every code step ships complete content. Task 2's edits are described by anchor text rather than line number because the merge from `upstream/dev` may have shifted lines; the anchors are quoted verbatim from the current file.

**Type consistency:** `sdd-checkoff PLAN_FILE` and `sdd-checkoff --print-range PLAN_FILE TASK_NUMBER` are used identically in the script, the tests, and both call sites. Exit codes 0/2/3 match the spec's table. `progress.md`, `# SDD ledger — plan:`, and `Task <N>: complete` match SKILL.md's documented strings.

**Fixed during review:** Task 1 Step 3 originally ran the awk pass twice, the first with a `2> >(cat)` redirect whose result was discarded. Replaced with a single pass that writes the transformed plan to `$tmp` and the tally to `$countfile` via awk's `print > cf`. The `trap` cleans both. This also keeps `tasks` meaning "tasks flipped this run", which is what the spec's summary-line contract requires.
