# Plan Check-off Verification and executing-plans Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every plan-checkbox flip a verified flip, from either the SDD ledger or an explicit `--done N`, and give executing-plans the same mechanism.

**Architecture:** One bash script, `plan-checkoff` (renamed from `sdd-checkoff`), in `skills/subagent-driven-development/scripts/`. It resolves each attested task's range fence-aware (unchanged awk), parses the task's `Files:` block, checks that every listed path exists under the repo root, and flips boxes only for tasks that verify. A `--verify` mode audits ticked tasks without writing. executing-plans calls the script by sibling-relative path.

**Tech Stack:** bash 3.2+, awk, coreutils, git (already used). No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-11-plan-checkoff-verify-design.md` (extends `docs/superpowers/specs/2026-08-09-sdd-checkoff-design.md`, whose fence model, atomic rewrite, and ledger contract stand unchanged).

## Global Constraints

- **Never infer completion.** Attestation is the ledger (`Task <N>: complete` lines) or explicit `--done N`. Nothing is derived from transcripts, tests, or git state.
- **Every flip is a verified flip.** A task verifies when every `- Create:`, `- Modify:`, and `- Test:` path in its `Files:` block exists under the repo root containing the plan. A task with no such lines is **refused** (not flipped), printed as `unverified`. One missing path refuses the whole task; other tasks in the run still proceed.
- **Monotonic.** `- [ ]` → `- [x]` only. No mode ever unticks.
- **Exit codes:** `0` every attested task verified and flipped (or nothing to do); `2` usage, missing plan, `--done` task absent from the plan, plan outside a git repository; `3` ledger refused (foreign, malformed, names an absent task) — unchanged; `4` one or more attested tasks not flipped, or `--verify` found a ticked task that fails.
- **Fence model unchanged:** `/^```/ { infence = !infence }`, parity with `task-brief`. Do not touch the fence logic.
- **Files line grammar:** `^- (Create|Modify|Test): `([^`]+)`` at line start, outside fences, inside the task's range; strip a trailing `:<digits>` or `:<digits>-<digits>` from the captured path. The `**Files:**` heading is not required.
- **Repo root:** `git -C "$(dirname "$plan")" rev-parse --show-toplevel`. Not a repo → exit 2.
- **No hand-written completion markers.** The script is the only writer of checkbox state.
- **House style:** `set -euo pipefail`, quoted expansions, header usage comment current, `shellcheck --severity=warning` clean, no `shellcheck disable` directives (this script has none today). Test idiom is `if …; then pass "…"; else fail "…"; fi`; tests build throwaway git repos with `new_repo` and never touch the host environment.
- **Skill prose:** only the sentences named in Task 5 change. No Red Flags table, rationalization list, or "human partner" language is touched in any SKILL.md.
- **Commits:** one per task, conventional subject, no `Co-Authored-By` or agent trailers. Do not push.
- **Teardown (fork rule, `.claude/CLAUDE.md`):** archive this plan's ledger and reviews under `docs/superpowers/ledgers/2026-09-11-plan-checkoff-verify/` before the workspace is deleted.

---

### Task 1: Rename `sdd-checkoff` to `plan-checkoff`

Pure rename, no behaviour change. The existing 23 assertions must pass unchanged at the end of this task.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-checkoff` (renamed to `skills/subagent-driven-development/scripts/plan-checkoff`)
- Modify: `tests/claude-code/test-sdd-checkoff.sh` (renamed to `tests/claude-code/test-plan-checkoff.sh`)
- Modify: `tests/claude-code/run-skill-tests.sh`
- Modify: `skills/subagent-driven-development/SKILL.md:149,486`
- Modify: `.claude/CLAUDE.md`

**Interfaces:**
- Produces: script path `skills/subagent-driven-development/scripts/plan-checkoff`; stderr prefix `plan-checkoff:`; temp-file prefixes `.plan-checkoff.` and `.plan-checkoff-count.` beside the plan; test file `tests/claude-code/test-plan-checkoff.sh` with `CHECKOFF="$SCRIPT_DIR/plan-checkoff"`.

- [ ] **Step 1: Rename both files with git so history follows**

```bash
git mv skills/subagent-driven-development/scripts/sdd-checkoff skills/subagent-driven-development/scripts/plan-checkoff
git mv tests/claude-code/test-sdd-checkoff.sh tests/claude-code/test-plan-checkoff.sh
```

- [ ] **Step 2: Update every textual reference**

In `skills/subagent-driven-development/scripts/plan-checkoff`: replace every `sdd-checkoff` with `plan-checkoff` (the header usage lines, the `die()` prefix, the two `usage:` strings, and the two `mktemp` templates `.sdd-checkoff.XXXXXX` → `.plan-checkoff.XXXXXX` and `.sdd-checkoff-count.XXXXXX` → `.plan-checkoff-count.XXXXXX`).

In `tests/claude-code/test-plan-checkoff.sh`: line 2 comment, line 6 `CHECKOFF="$SCRIPT_DIR/plan-checkoff"`, line 14 `echo "plan-checkoff tests"`, the leak test's glob `-name '.plan-checkoff*'`, and the two summary strings at the bottom (`All plan-checkoff tests passed` / `plan-checkoff test(s) failed`).

In `tests/claude-code/run-skill-tests.sh`: the `tests=(…)` array entry `"test-sdd-checkoff.sh"` → `"test-plan-checkoff.sh"`.

In `skills/subagent-driven-development/SKILL.md`: line 149 and line 486, `scripts/sdd-checkoff PLAN_FILE` → `scripts/plan-checkoff PLAN_FILE`. Nothing else in the file.

In `.claude/CLAUDE.md`: the one mention `scripts/sdd-checkoff PLAN_FILE` → `scripts/plan-checkoff PLAN_FILE`.

- [ ] **Step 3: Prove nothing else references the old name**

Run: `git grep -n 'sdd-checkoff' -- . ':!docs/superpowers/ledgers' ':!docs/superpowers/plans' ':!docs/superpowers/specs'`
Expected: no output. (Plans, specs, and archived ledgers keep the historical name.)

- [ ] **Step 4: Run the renamed test file and the linter**

Run: `bash tests/claude-code/test-plan-checkoff.sh`
Expected: 23 `[PASS]`, ends with `All plan-checkoff tests passed`.

Run: `shellcheck --severity=warning skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add -A skills/subagent-driven-development/scripts tests/claude-code skills/subagent-driven-development/SKILL.md .claude/CLAUDE.md
git commit -m "refactor(sdd): rename sdd-checkoff to plan-checkoff"
```

---

### Task 2: Files-block predicate in ledger mode

After this task the ledger mode verifies every attested task before flipping it. All existing fixtures gain `Files:` blocks whose paths exist, because a task without one is now refused.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/plan-checkoff` (whole file replaced; content below)
- Test: `tests/claude-code/test-plan-checkoff.sh`

**Interfaces:**
- Produces: shell functions inside the script — `task_headings PLAN`, `task_files PLAN N`, `ticked_tasks PLAN`, `verify_task N` (sets `VERDICT` to `ok`, `nofiles`, or `missing <path> [<path>…]`), `flip_tasks` (reads `$attested`, space-separated task numbers; writes per-task stderr lines and the stdout summary; sets `rc`). Tasks 3 and 4 add mode branches that call these and change nothing inside them.
- Produces: stderr lines `plan-checkoff: Task N: flipped K box(es)`, `plan-checkoff: Task N: nothing to flip`, `plan-checkoff: Task N: unverified: lists no files — not flipped`, `plan-checkoff: Task N: missing: <paths> — not flipped`; stdout summary `checked off T task(s), B box(es) in PLAN` unchanged.

- [ ] **Step 1: Migrate the shared fixture so its tasks list files that exist**

In `tests/claude-code/test-plan-checkoff.sh`, replace the `write_plan` function with:

```bash
# write_plan REPO NAME -- writes a two-task plan, 2 boxes each, whose Files:
# blocks name paths that exist in REPO (the predicate must pass by default).
write_plan() {
  mkdir -p "$1/src"; : > "$1/src/alpha.txt"; : > "$1/src/gamma.txt"
  cat > "$1/docs/superpowers/plans/$2.md" <<'PLAN'
# Demo Plan

### Task 1: First

**Files:**
- Create: `src/alpha.txt`

- [ ] **Step 1: alpha**
- [ ] **Step 2: beta**

### Task 2: Second

**Files:**
- Create: `src/gamma.txt`

- [ ] **Step 1: gamma**
- [ ] **Step 2: delta**
PLAN
}
```

Add one helper directly below `write_ledger`:

```bash
# touch_in REPO PATH -- create an empty file at REPO/PATH, making parents.
touch_in() { mkdir -p "$(dirname "$1/$2")"; : > "$1/$2"; }
```

- [ ] **Step 2: Migrate the four inline fixtures**

Each inline fixture (`fence.md`, `fh.md`, `ten.md`, `nested.md`) gets a `**Files:**` block with one existing path directly under its Task heading(s), and a `touch_in` call before the heredoc. Exact edits:

`fence.md` — insert after `### Task 1: First` and its blank line:
```markdown
**Files:**
- Create: `src/fence.txt`

```
and before the `cat >` line add `touch_in "$r" src/fence.txt`.

`fh.md` — same shape with `src/fh.txt`; the fenced `### Task 2` stays inside the fence, so only Task 1 gets a block.

`ten.md` — Task 1 gets `- Create: `src/one.txt``, Task 10 gets `- Create: `src/ten.txt``; `touch_in` both.

`nested.md` — Task 1 gets `- Create: `src/nested.txt``; `touch_in` it. The pinned observation (`n = 2`) does not change: the inner-fence box still flips under the documented toggle limit.

- [ ] **Step 3: Make the parity test materialize each real plan's listed paths, and skip tasks that list none**

Replace the body of the parity loop's inner `if "$TASK_BRIEF" …; then … fi` block with:

```bash
    if "$TASK_BRIEF" "$plan" "$n" "$brief" >/dev/null 2>&1; then
      # A task that lists no files is refused by design; parity is only
      # meaningful for tasks the predicate can pass.
      if ! grep -qE '^- (Create|Modify|Test): `' "$brief"; then rm -f "$brief"; continue; fi
      r=$(new_repo)
      cp "$plan" "$r/docs/superpowers/plans/$f.md"
      # Materialize every path the whole plan lists so any task's predicate passes.
      grep -oE '^- (Create|Modify|Test): `[^`]+`' "$plan" | sed -E 's/^- [A-Za-z]+: `//; s/`$//; s/:[0-9]+(-[0-9]+)?$//' \
        | while IFS= read -r rel; do touch_in "$r" "$rel"; done
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
```

Also add, just before the `agree=1` line, a guard that the loop still exercises something:

```bash
parity_runs=0
```
and increment `parity_runs=$((parity_runs + 1))` right after the `write_ledger` call inside the block. Change the final assertion to:

```bash
if [ "$agree" = "1" ] && [ "$parity_runs" -gt 0 ]; then pass "parser agreement with task-brief on real plans ($parity_runs runs)"; else fail "parser agreement with task-brief on real plans (agree=$agree runs=$parity_runs)"; fi
```

- [ ] **Step 4: Write the new failing tests for the predicate**

Append these blocks before the `# --- 11. usage / missing plan ---` section:

```bash
# --- 20. ledgered task with a missing Test path is not flipped, others are, exit 4 ---
r=$(new_repo); write_plan "$r" pred
cat >> "$r/docs/superpowers/plans/pred.md" <<'PLAN'

### Task 3: Third

**Files:**
- Create: `src/third.txt`
- Test: `tests/third_test.txt`

- [ ] **Step 1: epsilon**
PLAN
touch_in "$r" src/third.txt
write_ledger "$r" pred \
  "Task 1: complete (commits 1111111..2222222, review clean)" \
  "Task 3: complete (commits 3333333..4444444, review clean)"
p="$r/docs/superpowers/plans/pred.md"
err=$( cd "$r" && "$CHECKOFF" docs/superpowers/plans/pred.md 2>&1 >/dev/null ); rc=$?
if [ "$rc" = "4" ]; then pass "missing Test path exits 4"; else fail "missing Test path exits 4 (got $rc)"; fi
if grep -q '^- \[x\] \*\*Step 1: alpha' "$p"; then pass "verified task still flips alongside a refused one"; else fail "verified task still flips alongside a refused one"; fi
if grep -q '^- \[ \] \*\*Step 1: epsilon' "$p"; then pass "task with a missing path is not flipped"; else fail "task with a missing path is not flipped"; fi
if printf '%s\n' "$err" | grep -q 'Task 3: missing: tests/third_test.txt'; then pass "missing path is named on stderr"; else fail "missing path is named on stderr: $err"; fi
# rerun after creating the file flips it, exit 0
touch_in "$r" tests/third_test.txt
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/pred.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "0" ] && grep -q '^- \[x\] \*\*Step 1: epsilon' "$p"; then pass "rerun after the path exists flips the task, exit 0"; else fail "rerun after the path exists flips the task, exit 0 (rc=$rc)"; fi

# --- 21. ledgered task with no Files lines is refused, exit 4, plan untouched ---
r=$(new_repo)
cat > "$r/docs/superpowers/plans/nofiles.md" <<'PLAN'
# No Files Plan

### Task 1: First

- [ ] **Step 1: alpha**
PLAN
write_ledger "$r" nofiles "Task 1: complete (commits 1111111..2222222, review clean)"
p="$r/docs/superpowers/plans/nofiles.md"; before=$(cksum < "$p")
err=$( cd "$r" && "$CHECKOFF" docs/superpowers/plans/nofiles.md 2>&1 >/dev/null ); rc=$?
if [ "$rc" = "4" ] && [ "$before" = "$(cksum < "$p")" ]; then pass "task listing no files is refused, plan untouched, exit 4"; else fail "task listing no files is refused, plan untouched, exit 4 (rc=$rc)"; fi
if printf '%s\n' "$err" | grep -q 'Task 1: unverified: lists no files'; then pass "refusal says unverified"; else fail "refusal says unverified: $err"; fi

# --- 22. Modify path with a line suffix is stripped before the existence check ---
r=$(new_repo)
cat > "$r/docs/superpowers/plans/suffix.md" <<'PLAN'
# Suffix Plan

### Task 1: First

**Files:**
- Modify: `src/existing.txt:12-40`
- Modify: `src/other.txt:7`

- [ ] **Step 1: alpha**
PLAN
touch_in "$r" src/existing.txt; touch_in "$r" src/other.txt
write_ledger "$r" suffix "Task 1: complete (commits 1111111..2222222, review clean)"
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/suffix.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "0" ] && [ "$(boxes_checked "$r/docs/superpowers/plans/suffix.md")" = "1" ]; then pass "line-range suffix is stripped before the existence check"; else fail "line-range suffix is stripped before the existence check (rc=$rc)"; fi

# --- 23. Files lines inside a fence are ignored ---
# The fixture's fence is built from a variable so this plan file itself never
# nests one fence inside another (the toggle model would misread it).
r=$(new_repo)
fence='```'
cat > "$r/docs/superpowers/plans/fencedfiles.md" <<PLAN
# Fenced Files Plan

### Task 1: First

${fence}markdown
**Files:**
- Create: \`src/from-a-fence.txt\`
${fence}

- [ ] **Step 1: alpha**
PLAN
write_ledger "$r" fencedfiles "Task 1: complete (commits 1111111..2222222, review clean)"
touch_in "$r" src/from-a-fence.txt
( cd "$r" && "$CHECKOFF" docs/superpowers/plans/fencedfiles.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "4" ]; then pass "Files lines inside a fence do not count as evidence"; else fail "Files lines inside a fence do not count as evidence (rc=$rc)"; fi
```

- [ ] **Step 5: Run the tests to verify the new ones fail**

Run: `bash tests/claude-code/test-plan-checkoff.sh`
Expected: the pre-existing assertions pass; `missing Test path exits 4`, `task with a missing path is not flipped`, `missing path is named on stderr`, `task listing no files is refused…`, `refusal says unverified`, and `Files lines inside a fence…` fail (the old script flips everything and exits 0). `line-range suffix…` passes vacuously today; it is a regression guard.

- [ ] **Step 6: Replace the script with the predicate-aware version**

Write `skills/subagent-driven-development/scripts/plan-checkoff` with exactly this content:

```bash
#!/usr/bin/env bash
# Reconcile an implementation plan's checkboxes from evidence of completion,
# and verify every flip against the task's own Files: block.
#
# Attestation, never inference:
#   plan-checkoff PLAN_FILE                    SDD: tasks the ledger marks complete
#   plan-checkoff --print-range PLAN_FILE N    debug/parity: print one task's range
#
# A task verifies when every path in its Files: block (unfenced lines of the
# form "- Create: `p`", "- Modify: `p`", "- Test: `p`", optional :LINES suffix)
# exists under the repo root that holds the plan. A task listing no files is
# refused, not flipped: an unverifiable tick is decoration. One missing path
# refuses the whole task; other tasks in the run still proceed.
#
# Exit codes: 0 every attested task verified and flipped (or nothing to do)
#             2 usage, missing plan, plan outside a git repository
#             3 ledger refused (foreign, malformed, names an absent task)
#             4 one or more attested tasks not flipped; others still processed
#
# Fence handling is byte-identical to task-brief's toggle. That model does not
# understand ~~~, indented, or >=4-backtick nested fences; see the spec's
# "Fence model — stated limits". Parity with task-brief is the standard.
set -euo pipefail

die() { echo "plan-checkoff: $1" >&2; exit "$2"; }
say() { echo "plan-checkoff: $*" >&2; }

usage() {
  echo "usage: plan-checkoff PLAN_FILE" >&2
  echo "       plan-checkoff --print-range PLAN_FILE TASK_NUMBER" >&2
  exit 2
}

# Task numbers present as unfenced headings, one per line, ascending.
task_headings() {
  awk '
    /^```/ { infence = !infence; next }
    !infence && /^#+[ \t]+Task[ \t]+[0-9]+/ { t=$0; sub(/^#+[ \t]+Task[ \t]+/,"",t); sub(/[^0-9].*$/,"",t); print t }
  ' "$1" | sort -un
}

# Paths a task's Files: block names, one per line, :LINES suffix stripped.
task_files() {  # PLAN N
  awk -v n="$2" '
    /^```/ { infence = !infence; next }
    !infence && /^#+[ \t]+Task[ \t]+[0-9]+/ { intask = ($0 ~ ("^#+[ \t]+Task[ \t]+" n "([^0-9]|$)")) }
    intask && !infence && /^- (Create|Modify|Test): `[^`]+`/ {
      p = $0; sub(/^- (Create|Modify|Test): `/, "", p); sub(/`.*$/, "", p)
      sub(/:[0-9]+(-[0-9]+)?$/, "", p); print p
    }
  ' "$1"
}

# Tasks with at least one ticked box, one per line, ascending.
ticked_tasks() {
  awk '
    /^```/ { infence = !infence; next }
    !infence && /^#+[ \t]+Task[ \t]+[0-9]+/ { t=$0; sub(/^#+[ \t]+Task[ \t]+/,"",t); sub(/[^0-9].*$/,"",t); cur=t }
    !infence && cur != "" && /^[ \t]*- \[[xX]\]/ { if (!seen[cur]++) print cur }
  ' "$1" | sort -un
}

# verify_task N -> VERDICT is "ok", "nofiles", or "missing <p> [<p>…]".
verify_task() {
  local n=$1 p paths missing=""
  paths=$(task_files "$plan" "$n")
  if [ -z "$paths" ]; then VERDICT=nofiles; return 0; fi
  while IFS= read -r p; do
    [ -e "$root/$p" ] || missing="$missing $p"
  done <<< "$paths"
  if [ -n "$missing" ]; then VERDICT="missing$missing"; else VERDICT=ok; fi
}

# flip_tasks: verify each task in $attested (space-separated), flip the ones
# that verify, report per task on stderr, summary on stdout. Sets rc to 4 if
# any task was refused.
flip_tasks() {
  # tmp and countfile are deliberately NOT local: the EXIT trap below expands
  # them after this function has returned, and a local would be empty by then,
  # leaving the count file beside the plan (the leak test catches exactly that).
  local n flip="" t k tasks=0 boxes=0
  rc=0
  for n in $attested; do
    verify_task "$n"
    case "$VERDICT" in
      ok) flip="$flip,$n" ;;
      nofiles) say "Task $n: unverified: lists no files — not flipped"; rc=4 ;;
      missing*) say "Task $n: missing:${VERDICT#missing} — not flipped"; rc=4 ;;
    esac
  done
  flip=${flip#,}
  if [ -z "$flip" ]; then
    echo "checked off 0 task(s), 0 box(es) in $plan"
    return 0
  fi

  tmp=$(mktemp "$(dirname "$plan")/.plan-checkoff.XXXXXX")
  cp -p "$plan" "$tmp"
  # Beside the plan, not in shared temp: the leak test scans this directory, and a
  # bare mktemp in /var/folders made that test flaky under concurrent temp churn.
  countfile=$(mktemp "$(dirname "$plan")/.plan-checkoff-count.XXXXXX")
  trap 'rm -f "$tmp" "$countfile"' EXIT

  # Single pass: transformed plan to $tmp, per-task tally to $countfile.
  awk -v want="$flip" -v cf="$countfile" '
    BEGIN { n = split(want, a, ","); for (i = 1; i <= n; i++) { done[a[i]] = 1; cnt[a[i]] = 0 } }
    /^```/ { infence = !infence }
    !infence && /^#+[ \t]+Task[ \t]+[0-9]+/ {
      t = $0; sub(/^#+[ \t]+Task[ \t]+/, "", t); sub(/[^0-9].*$/, "", t)
      cur = t; active = (t in done)
    }
    !infence && active && /^[ \t]*- \[ \]/ { sub(/- \[ \]/, "- [x]"); cnt[cur]++ }
    { print }
    END { for (t in cnt) print t "," cnt[t] > cf }
  ' "$plan" > "$tmp"

  while IFS=, read -r t k; do
    if [ "$k" -gt 0 ]; then
      say "Task $t: flipped $k box(es)"; tasks=$((tasks + 1)); boxes=$((boxes + k))
    else
      say "Task $t: nothing to flip"
    fi
  done < <(sort -n "$countfile")

  if [ "$boxes" -eq 0 ]; then
    # Skip the mv entirely: replacing the file would change inode and mtime, and
    # awk's print appends a trailing newline to a plan lacking one — a diff from
    # a run that changed nothing.
    echo "checked off 0 task(s), 0 box(es) in $plan"
    return 0
  fi
  mv "$tmp" "$plan"
  echo "checked off $tasks task(s), $boxes box(es) in $plan"
}

# ---- argument handling ------------------------------------------------------

mode=ledger
case "${1:-}" in
  --print-range)
    [ $# -eq 3 ] || usage
    [ -f "$2" ] || die "no such plan file: $2" 2
    awk -v n="$3" '
      /^```/ { infence = !infence }
      !infence && /^#+[ \t]+Task[ \t]+[0-9]+/ {
        intask = ($0 ~ ("^#+[ \t]+Task[ \t]+" n "([^0-9]|$)"))
      }
      intask { print }
    ' "$2"
    exit 0 ;;
  -*) usage ;;
esac
[ $# -eq 1 ] || usage
plan=$1
[ -f "$plan" ] || die "no such plan file: $plan" 2
root=$(git -C "$(dirname "$plan")" rev-parse --show-toplevel 2>/dev/null) \
  || die "$plan is not inside a git repository — Files: paths resolve against the repo root" 2

# ---- ledger mode --------------------------------------------------------------

dir=$("$(cd "$(dirname "$0")" && pwd)/sdd-workspace" "$plan")
ledger="$dir/progress.md"

if [ ! -f "$ledger" ]; then
  say "no ledger at $ledger — nothing to reconcile"
  exit 0
fi

# Identity. The controller writes "# SDD ledger — plan: <path>" using whatever
# path form it had; we may be invoked with another. Compare by slug, the same
# key sdd-workspace uses for the directory. Strip CR so a CRLF ledger does not
# refuse spuriously.
first=$(head -n 1 "$ledger" | tr -d '\r')
case "$first" in
  '# SDD ledger'*) ;;
  *) die "unrecognized ledger header in $ledger (expected '# SDD ledger — plan: <path>')" 3 ;;
esac
ledger_slug=$(basename "${first##*: }" .md)
plan_slug=$(basename "$plan" .md)
[ "$ledger_slug" = "$plan_slug" ] \
  || die "ledger at $ledger names plan '$ledger_slug', not '$plan_slug' — refusing" 3

# Completed tasks: line-anchored, so a ruling that quotes "Task 3: complete"
# in prose cannot mark a task done.
attested=$(tr -d '\r' < "$ledger" \
  | awk '/^Task [0-9]+: complete/ { t=$2; sub(/:$/,"",t); print t }' \
  | sort -un | tr '\n' ' ')
attested=${attested% }

if [ -z "$attested" ]; then
  echo "checked off 0 task(s), 0 box(es) in $plan"
  exit 0
fi

# Every completed task must exist as an unfenced heading, or refuse wholesale.
present=$(task_headings "$plan")
missing=""
for n in $attested; do
  printf '%s\n' "$present" | grep -qx "$n" || missing="$missing $n"
done
[ -z "$missing" ] || die "ledger names task(s)$missing with no matching heading in $plan — refusing (plan edited after the run?)" 3

flip_tasks
exit "$rc"
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `bash tests/claude-code/test-plan-checkoff.sh`
Expected: all assertions pass (23 pre-existing + 10 new = 33), ends with `All plan-checkoff tests passed`. If the parity assertion reports `runs=0`, the three real plans' tasks 1–3 list no files in the template form; inspect them with `--print-range` and adjust the `grep -qE` guard only if the grammar in this plan's Global Constraints is being violated by the test, not by the plans.

Run: `shellcheck --severity=warning skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh`
Expected: no output.

- [ ] **Step 8: Commit**

```bash
git add skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh
git commit -m "feat(sdd): verify every check-off against the task's Files block"
```

---

### Task 3: `--done N [N …]` mode for executing-plans

**Files:**
- Modify: `skills/subagent-driven-development/scripts/plan-checkoff`
- Test: `tests/claude-code/test-plan-checkoff.sh`

**Interfaces:**
- Consumes: `flip_tasks`, `task_headings`, `verify_task`, `$attested`, `$root` from Task 2.
- Produces: invocation `plan-checkoff --done N [N …] PLAN_FILE`; exit 2 when a named task has no heading; otherwise the same per-task lines and exit contract as ledger mode.

- [ ] **Step 1: Write the failing tests**

Append before the `# --- 11. usage / missing plan ---` section:

```bash
# --- 24. --done: verified task flips, exit 0 ---
r=$(new_repo); write_plan "$r" done1
p="$r/docs/superpowers/plans/done1.md"
( cd "$r" && "$CHECKOFF" --done 2 docs/superpowers/plans/done1.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "0" ] && grep -q '^- \[x\] \*\*Step 1: gamma' "$p" && grep -q '^- \[ \] \*\*Step 1: alpha' "$p"; then pass "--done flips only the named task"; else fail "--done flips only the named task (rc=$rc)"; fi

# --- 25. --done: missing Create path refuses, exit 4, file unchanged ---
r=$(new_repo); write_plan "$r" done2; rm "$r/src/gamma.txt"
p="$r/docs/superpowers/plans/done2.md"; before=$(cksum < "$p")
err=$( cd "$r" && "$CHECKOFF" --done 2 docs/superpowers/plans/done2.md 2>&1 >/dev/null ); rc=$?
if [ "$rc" = "4" ] && [ "$before" = "$(cksum < "$p")" ]; then pass "--done with a missing path refuses, exit 4"; else fail "--done with a missing path refuses, exit 4 (rc=$rc)"; fi
if printf '%s\n' "$err" | grep -q 'Task 2: missing: src/gamma.txt'; then pass "--done names the missing path"; else fail "--done names the missing path: $err"; fi

# --- 26. --done: task listing no files refuses, exit 4 ---
r=$(new_repo)
cat > "$r/docs/superpowers/plans/done3.md" <<'PLAN'
# Done No Files

### Task 1: First

- [ ] **Step 1: alpha**
PLAN
p="$r/docs/superpowers/plans/done3.md"; before=$(cksum < "$p")
( cd "$r" && "$CHECKOFF" --done 1 docs/superpowers/plans/done3.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "4" ] && [ "$before" = "$(cksum < "$p")" ]; then pass "--done on a task listing no files refuses, exit 4"; else fail "--done on a task listing no files refuses, exit 4 (rc=$rc)"; fi

# --- 27. --done 1 2 where 2 fails: 1 flips, 2 does not, exit 4 ---
r=$(new_repo); write_plan "$r" done4; rm "$r/src/gamma.txt"
p="$r/docs/superpowers/plans/done4.md"
( cd "$r" && "$CHECKOFF" --done 1 2 docs/superpowers/plans/done4.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "4" ] && grep -q '^- \[x\] \*\*Step 1: alpha' "$p" && grep -q '^- \[ \] \*\*Step 1: gamma' "$p"; then pass "--done processes every task and exits 4 if any refused"; else fail "--done processes every task and exits 4 if any refused (rc=$rc)"; fi

# --- 28. --done 9 on a two-task plan: exit 2, file unchanged ---
r=$(new_repo); write_plan "$r" done5
p="$r/docs/superpowers/plans/done5.md"; before=$(cksum < "$p")
( cd "$r" && "$CHECKOFF" --done 9 docs/superpowers/plans/done5.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "2" ] && [ "$before" = "$(cksum < "$p")" ]; then pass "--done with an absent task number is a usage error"; else fail "--done with an absent task number is a usage error (rc=$rc)"; fi

# --- 29. --done twice is idempotent (mtime unchanged on the second run) ---
r=$(new_repo); write_plan "$r" done6
p="$r/docs/superpowers/plans/done6.md"
( cd "$r" && "$CHECKOFF" --done 1 docs/superpowers/plans/done6.md >/dev/null 2>&1 )
mt1=$(stat -f %m "$p" 2>/dev/null || stat -c %Y "$p"); sleep 1
( cd "$r" && "$CHECKOFF" --done 1 docs/superpowers/plans/done6.md >/dev/null 2>&1 ); rc=$?
mt2=$(stat -f %m "$p" 2>/dev/null || stat -c %Y "$p")
if [ "$rc" = "0" ] && [ "$mt1" = "$mt2" ]; then pass "second --done on the same task changes nothing, exit 0"; else fail "second --done on the same task changes nothing, exit 0 (rc=$rc)"; fi

# --- 30. --done with a non-numeric argument is a usage error ---
r=$(new_repo); write_plan "$r" done7
( cd "$r" && "$CHECKOFF" --done two docs/superpowers/plans/done7.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "2" ]; then pass "--done rejects a non-numeric task"; else fail "--done rejects a non-numeric task (rc=$rc)"; fi
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/claude-code/test-plan-checkoff.sh`
Expected: the seven new `--done` assertions fail (today `--done` hits the `-*) usage` branch and exits 2, so tests 28 and 30 pass vacuously; the rest fail). Everything else passes.

- [ ] **Step 3: Add the mode**

In the header comment, add a usage line after the `PLAN_FILE` one:

```
#   plan-checkoff --done N [N ...] PLAN_FILE   executing-plans: tasks the caller names
```
and in the exit-code comment change the `2` line to: `2 usage, missing plan, --done task absent from the plan, plan outside a git repository`.

In `usage()`, add the line `echo "       plan-checkoff --done N [N ...] PLAN_FILE" >&2` after the first echo.

In the argument `case`, add this arm before `-*) usage ;;`:

```bash
  --done)
    mode=done; shift
    done_list=""
    while [ $# -gt 1 ]; do
      case "$1" in ''|*[!0-9]*) die "--done takes task numbers, got '$1'" 2 ;; esac
      done_list="$done_list $1"; shift
    done
    [ -n "$done_list" ] || usage ;;
```

After the `root=…` line and before the `# ---- ledger mode` banner, insert:

```bash
# ---- --done mode --------------------------------------------------------------

if [ "$mode" = done ]; then
  attested=$(printf '%s\n' $done_list | sort -un | tr '\n' ' ')
  attested=${attested% }
  present=$(task_headings "$plan")
  for n in $attested; do
    printf '%s\n' "$present" | grep -qx "$n" \
      || die "no 'Task $n' heading in $plan" 2
  done
  flip_tasks
  exit "$rc"
fi
```

(`$done_list` is intentionally unquoted in the `printf`: it is a space-separated list of validated integers, and word splitting is the point. shellcheck accepts this at warning severity because the values were validated as digits above; if it flags SC2086 anyway, rewrite as `printf '%s\n' "${done_list# }" | tr ' ' '\n' | sort -un | tr '\n' ' '`.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/claude-code/test-plan-checkoff.sh`
Expected: 40 `[PASS]`, ends with `All plan-checkoff tests passed`.

Run: `shellcheck --severity=warning skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh
git commit -m "feat(sdd): plan-checkoff --done N for executors without a ledger"
```

---

### Task 4: `--verify` audit mode

**Files:**
- Modify: `skills/subagent-driven-development/scripts/plan-checkoff`
- Test: `tests/claude-code/test-plan-checkoff.sh`

**Interfaces:**
- Consumes: `ticked_tasks`, `verify_task`, `$root` from Task 2.
- Produces: invocation `plan-checkoff --verify PLAN_FILE`; writes nothing; exit 0 and silent when clean; exit 4 with one stderr line per offending task: `plan-checkoff: verify: Task N ticked but missing: <paths>` or `plan-checkoff: verify: Task N ticked but lists no files`.

- [ ] **Step 1: Write the failing tests**

Append before the `# --- 11. usage / missing plan ---` section:

```bash
# --- 31. --verify: ticked task with an absent Create path, exit 4, file unchanged ---
r=$(new_repo); write_plan "$r" ver1
p="$r/docs/superpowers/plans/ver1.md"
( cd "$r" && "$CHECKOFF" --done 1 docs/superpowers/plans/ver1.md >/dev/null 2>&1 )
rm "$r/src/alpha.txt"; before=$(cksum < "$p")
err=$( cd "$r" && "$CHECKOFF" --verify docs/superpowers/plans/ver1.md 2>&1 >/dev/null ); rc=$?
if [ "$rc" = "4" ] && [ "$before" = "$(cksum < "$p")" ]; then pass "--verify flags a ticked task whose path is gone, writes nothing"; else fail "--verify flags a ticked task whose path is gone, writes nothing (rc=$rc)"; fi
if printf '%s\n' "$err" | grep -q 'verify: Task 1 ticked but missing: src/alpha.txt'; then pass "--verify names the missing path"; else fail "--verify names the missing path: $err"; fi

# --- 32. --verify: ticked task that lists no files, exit 4 ---
r=$(new_repo)
cat > "$r/docs/superpowers/plans/ver2.md" <<'PLAN'
# Verify No Files

### Task 1: First

- [x] **Step 1: hand-ticked long ago**
PLAN
err=$( cd "$r" && "$CHECKOFF" --verify docs/superpowers/plans/ver2.md 2>&1 >/dev/null ); rc=$?
if [ "$rc" = "4" ] && printf '%s\n' "$err" | grep -q 'verify: Task 1 ticked but lists no files'; then pass "--verify flags a ticked task with no Files lines"; else fail "--verify flags a ticked task with no Files lines (rc=$rc): $err"; fi

# --- 33. --verify: consistent plan is silent, exit 0 ---
r=$(new_repo); write_plan "$r" ver3
( cd "$r" && "$CHECKOFF" --done 1 2 docs/superpowers/plans/ver3.md >/dev/null 2>&1 )
out=$( cd "$r" && "$CHECKOFF" --verify docs/superpowers/plans/ver3.md 2>&1 ); rc=$?
if [ "$rc" = "0" ] && [ -z "$out" ]; then pass "--verify on a consistent plan is silent, exit 0"; else fail "--verify on a consistent plan is silent, exit 0 (rc=$rc out=$out)"; fi

# --- 34. --verify: an unticked task is not audited even if its files are missing ---
r=$(new_repo); write_plan "$r" ver4; rm "$r/src/gamma.txt"
( cd "$r" && "$CHECKOFF" --verify docs/superpowers/plans/ver4.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "0" ]; then pass "--verify ignores tasks with no ticked box"; else fail "--verify ignores tasks with no ticked box (rc=$rc)"; fi
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/claude-code/test-plan-checkoff.sh`
Expected: tests 31–33 fail (`--verify` is a usage error today, exit 2); test 34 passes vacuously and is a regression guard. Everything else passes.

- [ ] **Step 3: Add the mode**

Header: add usage line `#   plan-checkoff --verify PLAN_FILE           audit: every ticked task must verify; writes nothing` and extend the `4` exit-code line to `4 one or more attested tasks not flipped, or --verify found a ticked task that fails`.

`usage()`: add `echo "       plan-checkoff --verify PLAN_FILE" >&2`.

Argument `case`: add `--verify) mode=verify; shift ;;` before the `--done)` arm.

Directly after the `--done` mode block and before the `# ---- ledger mode` banner, insert:

```bash
# ---- --verify mode ------------------------------------------------------------

if [ "$mode" = verify ]; then
  rc=0
  # Process substitution, not a pipe: the loop must run in this shell so rc sticks.
  while IFS= read -r n; do
    verify_task "$n"
    case "$VERDICT" in
      ok) ;;
      nofiles) say "verify: Task $n ticked but lists no files"; rc=4 ;;
      missing*) say "verify: Task $n ticked but missing:${VERDICT#missing}"; rc=4 ;;
    esac
  done < <(ticked_tasks "$plan")
  exit "$rc"
fi
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/claude-code/test-plan-checkoff.sh`
Expected: 45 `[PASS]`, ends with `All plan-checkoff tests passed`.

Run: `shellcheck --severity=warning skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh`
Expected: no output.

Run: `bash scripts/lint-shell.sh skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh`
Expected: `Linting 2 shell files`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh
git commit -m "feat(sdd): plan-checkoff --verify audits ticked tasks against their Files block"
```

---

### Task 5: Wire the skills

Three sentences in two skill files. Nothing else in either file changes.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:486-493`
- Modify: `skills/executing-plans/SKILL.md:31,33-37`

**Interfaces:**
- Consumes: `plan-checkoff --done N PLAN_FILE` and `plan-checkoff --verify PLAN_FILE` from Tasks 3 and 4; exit 4 semantics from the Global Constraints.

- [ ] **Step 1: Confirm the anchors are where this plan says**

Run: `grep -n 'scripts/plan-checkoff PLAN_FILE. one last' skills/subagent-driven-development/SKILL.md; grep -n '^4. Mark as completed$\|^### Step 3: Complete Development$' skills/executing-plans/SKILL.md`
Expected: three line numbers (one in SDD around 486, two in executing-plans at 31 and 33). If a line is missing, stop and report; do not guess a new anchor.

- [ ] **Step 2: Extend the SDD teardown paragraph**

In `skills/subagent-driven-development/SKILL.md`, the paragraph beginning `Before deleting the workspace, run \`scripts/plan-checkoff PLAN_FILE\` one last` currently ends with `…finishing-a-development-branch refuses to remove a dirty worktree.` Append one sentence to that paragraph, after that final sentence:

```
An exit of 4 means a ledgered task's `Files:` block names a path that does
not exist, or lists no files at all — either the task is not done or the plan
is wrong about it; resolve that before deleting the workspace, then rerun.
```

- [ ] **Step 3: Wire executing-plans step 2.4 and step 3**

In `skills/executing-plans/SKILL.md`, replace line 31 `4. Mark as completed` with:

```
4. Mark as completed — the todo, and the plan file: run
   `../subagent-driven-development/scripts/plan-checkoff --done N PLAN_FILE`
   (path relative to this skill's directory) for the task you just finished.
   Exit 4 means a path the task's `Files:` block names does not exist yet, or
   the task lists none: the task is not done — fix what is missing, then rerun.
```

In `### Step 3: Complete Development`, insert as the first bullet under `After all tasks complete and verified:`:

```
- Run `../subagent-driven-development/scripts/plan-checkoff --verify PLAN_FILE`;
  a non-zero exit lists ticked tasks whose deliverables are missing — resolve
  them before going on.
```

- [ ] **Step 4: Prove the edits are the only changes**

Run: `git diff --stat -- skills/`
Expected: exactly two files, `skills/executing-plans/SKILL.md` and `skills/subagent-driven-development/SKILL.md`, with roughly `+9 -1` and `+3 -0`.

Run: `git diff -- skills/ | grep -c -i -E 'red flag|rationaliz|human partner'`
Expected: `0`.

- [ ] **Step 5: Run the fast skill-test files that read these skills, and the full check-off suite**

Run: `bash tests/claude-code/test-plan-checkoff.sh`
Expected: 45 `[PASS]`.

Run: `bash tests/supercritic/run-tests.sh`
Expected: `=== All supercritic tests passed ===` (unrelated, proves the tree is still green).

- [ ] **Step 6: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md skills/executing-plans/SKILL.md
git commit -m "feat(skills): executing-plans and SDD call plan-checkoff with verification"
```

---

## Self-review against the spec

- **D1 two sources, never inference** — Task 2 (ledger), Task 3 (`--done`). No mode reads tests, transcripts, or git state for completion. ✔
- **D2 predicate, per-tag strictness, refuse no-files** — Task 2 `task_files` + `verify_task`; tests 20–23, 25–26. ✔
- **D3 `--verify`, any ticked box, no writes** — Task 4; tests 31–34. ✔
- **D4 no hand markers** — nothing writes markers; the skill text in Task 5 names only the script. ✔
- **D5 rename + sibling path** — Task 1, Task 5 step 3. ✔
- **Interface / output lines / exit codes** — Task 2 `say` lines and `flip_tasks`; Task 3 exit 2 on absent task; Task 4 verify lines. ✔
- **Parsing contract** (regex, suffix strip, heading not required, fenced lines ignored) — `task_files`; tests 22, 23. ✔
- **Guards:** monotonic (awk only rewrites `- [ ]`), `--done` idempotent (test 29), absent task usage error (test 28), ledger and `--done` exclusive (argument parsing accepts one mode), template drift refused and printed (tests 21, 26, 32). ✔
- **Call sites** — Task 5 exactly as the spec's Call sites section. ✔
- **Spec test plan items 1–13** map to tests 20–34 plus pre-existing 6/7 (idempotency). Item 12 (fence parity) is test 23 plus the pre-existing parity test, migrated in Task 2. ✔
- **Not in this plan, by spec:** the two csd-driven before/after eval runs are PR evidence, run by the controller after the build, and recorded in the ledger archive; they need the built branch to exist first.
- **Placeholder scan:** no TBD/TODO; every code step carries its code; no "similar to Task N".
- **Type consistency:** `VERDICT`, `attested`, `rc`, `root`, `plan`, `say`, `die MSG CODE` used identically in Tasks 2–4.
