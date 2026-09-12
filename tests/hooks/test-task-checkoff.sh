#!/usr/bin/env bash
# Tests for hooks/task-checkoff: the TaskCompleted hook that runs plan-checkoff --done N
# for a completed task whose subject matches a plan heading.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/task-checkoff"
ACTIVE="$REPO_ROOT/skills/subagent-driven-development/scripts/active-plan"

failures=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }

echo "task-checkoff hook tests"

# Throwaway git repo with a two-task plan whose Files: paths exist by default.
new_repo() {
  local d; d=$(mktemp -d)
  git -C "$d" init -q
  mkdir -p "$d/docs/superpowers/plans" "$d/src"
  : > "$d/src/alpha.txt"; : > "$d/src/gamma.txt"
  cat > "$d/docs/superpowers/plans/demo.md" <<'PLAN'
# Demo Plan

### Task 1: First thing

**Files:**
- Create: `src/alpha.txt`

- [ ] **Step 1: alpha**
- [ ] **Step 2: beta**

### Task 2: Second "quoted" thing

**Files:**
- Create: `src/gamma.txt`

- [ ] **Step 1: gamma**

### Task 3: No files here

- [ ] **Step 1: nothing to verify**
PLAN
  echo "$d"
}

# run_hook REPO SUBJECT_JSON -> runs the hook with a TaskCompleted payload; sets out, err, rc.
run_hook() {
  local repo=$1 subject=$2
  local payload='{"session_id":"s1","transcript_path":"/dev/null","cwd":"'"$repo"'","prompt_id":"p1","hook_event_name":"TaskCompleted","task_id":"7","task_subject":"'"$subject"'","task_description":"'"$subject"'"}'
  local errf; errf=$(mktemp)
  out=$(printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>"$errf"); rc=$?
  err=$(cat "$errf"); rm -f "$errf"
}

boxes_checked() { grep -c '^[[:space:]]*- \[x\]' "$1" || true; }
plan_of() { echo "$1/docs/superpowers/plans/demo.md"; }
activate() { ( cd "$1" && "$ACTIVE" set docs/superpowers/plans/demo.md >/dev/null ); }

# --- 1. no marker: silent exit 0 ---
r=$(new_repo)
run_hook "$r" "Task 1: First thing"
if [ "$rc" = "0" ] && [ -z "$out" ] && [ -z "$err" ] && [ "$(boxes_checked "$(plan_of "$r")")" = "0" ]; then pass "no marker: exit 0, silent, nothing flipped"; else fail "no marker: exit 0, silent, nothing flipped (rc=$rc err=$err)"; fi

# --- 2. matching subject, files present: flipped, exit 0, silent ---
r=$(new_repo); activate "$r"
run_hook "$r" "Task 1: First thing"
if [ "$rc" = "0" ] && [ -z "$out" ] && [ -z "$err" ] && [ "$(boxes_checked "$(plan_of "$r")")" = "2" ]; then pass "matching subject with files present flips the task, exit 0, silent"; else fail "matching subject with files present flips the task, exit 0, silent (rc=$rc boxes=$(boxes_checked "$(plan_of "$r")") err=$err)"; fi

# --- 3. matching subject, file missing: exit 2, missing on stderr, unflipped ---
r=$(new_repo); activate "$r"; rm "$r/src/alpha.txt"
run_hook "$r" "Task 1: First thing"
if [ "$rc" = "2" ] && printf '%s' "$err" | grep -q 'Task 1: missing: src/alpha.txt' && [ "$(boxes_checked "$(plan_of "$r")")" = "0" ]; then pass "missing path: exit 2, refusal on stderr, unflipped"; else fail "missing path: exit 2, refusal on stderr, unflipped (rc=$rc err=$err)"; fi

# --- 4. task lists no files: exit 2, unverified ---
r=$(new_repo); activate "$r"
run_hook "$r" "Task 3: No files here"
if [ "$rc" = "2" ] && printf '%s' "$err" | grep -q 'Task 3: unverified: lists no files' && [ "$(boxes_checked "$(plan_of "$r")")" = "0" ]; then pass "no Files block: exit 2, unverified on stderr"; else fail "no Files block: exit 2, unverified on stderr (rc=$rc err=$err)"; fi

# --- 5. a second attempt at the same refusal is refused again ---
run_hook "$r" "Task 3: No files here"
if [ "$rc" = "2" ] && printf '%s' "$err" | grep -q 'unverified'; then pass "a retry is a fresh claim and is refused again"; else fail "a retry is a fresh claim and is refused again (rc=$rc)"; fi

# --- 6. number matches, name differs: silent, unflipped ---
r=$(new_repo); activate "$r"
run_hook "$r" "Task 1: Something else"
if [ "$rc" = "0" ] && [ -z "$err" ] && [ "$(boxes_checked "$(plan_of "$r")")" = "0" ]; then pass "number matches but name differs: silent, unflipped"; else fail "number matches but name differs: silent, unflipped (rc=$rc boxes=$(boxes_checked "$(plan_of "$r")"))"; fi

# --- 7. case and whitespace are normalised ---
r=$(new_repo); activate "$r"
run_hook "$r" "task 1:   first   THING  "
if [ "$rc" = "0" ] && [ "$(boxes_checked "$(plan_of "$r")")" = "2" ]; then pass "subject match ignores case and whitespace runs"; else fail "subject match ignores case and whitespace runs (rc=$rc boxes=$(boxes_checked "$(plan_of "$r")"))"; fi

# --- 8. subject not in Task N form: silent ---
r=$(new_repo); activate "$r"
run_hook "$r" "Write the failing test"
if [ "$rc" = "0" ] && [ -z "$err" ] && [ "$(boxes_checked "$(plan_of "$r")")" = "0" ]; then pass "subject without a Task N prefix is ignored"; else fail "subject without a Task N prefix is ignored (rc=$rc)"; fi

# --- 9. already ticked: exit 0, silent ---
r=$(new_repo); activate "$r"
run_hook "$r" "Task 1: First thing"
run_hook "$r" "Task 1: First thing"
if [ "$rc" = "0" ] && [ -z "$err" ] && [ "$(boxes_checked "$(plan_of "$r")")" = "2" ]; then pass "already ticked task: exit 0, silent"; else fail "already ticked task: exit 0, silent (rc=$rc err=$err)"; fi

# --- 10. escaped quotes in the subject are unescaped before matching ---
r=$(new_repo); activate "$r"
run_hook "$r" 'Task 2: Second \"quoted\" thing'
if [ "$rc" = "0" ] && [ "$(boxes_checked "$(plan_of "$r")")" = "1" ]; then pass "escaped quotes in task_subject are unescaped and match"; else fail "escaped quotes in task_subject are unescaped and match (rc=$rc boxes=$(boxes_checked "$(plan_of "$r")"))"; fi

# --- 11. malformed stdin: exit 0, silent ---
r=$(new_repo); activate "$r"
errf=$(mktemp)
out=$(printf 'not json at all' | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" 2>"$errf"); rc=$?; err=$(cat "$errf"); rm -f "$errf"
if [ "$rc" = "0" ] && [ -z "$out" ] && [ -z "$err" ]; then pass "malformed stdin: exit 0, silent"; else fail "malformed stdin: exit 0, silent (rc=$rc err=$err)"; fi

# --- 12. marker names a deleted plan: exit 0, silent ---
r=$(new_repo); activate "$r"; rm "$(plan_of "$r")"
run_hook "$r" "Task 1: First thing"
if [ "$rc" = "0" ] && [ -z "$err" ]; then pass "marker naming a deleted plan: exit 0, silent"; else fail "marker naming a deleted plan: exit 0, silent (rc=$rc err=$err)"; fi

# --- 13. plan-checkoff not executable: exit 0, one stderr line, completion proceeds ---
r=$(new_repo); activate "$r"
fake=$(mktemp -d); mkdir -p "$fake/skills/subagent-driven-development/scripts"
: > "$fake/skills/subagent-driven-development/scripts/plan-checkoff"   # exists, not executable
errf=$(mktemp)
payload='{"cwd":"'"$r"'","task_subject":"Task 1: First thing"}'
out=$(printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT="$fake" bash "$HOOK" 2>"$errf"); rc=$?; err=$(cat "$errf"); rm -f "$errf"
if [ "$rc" = "0" ] && [ "$(printf '%s\n' "$err" | grep -c .)" = "1" ] && printf '%s' "$err" | grep -q 'not executable'; then pass "unusable plan-checkoff: exit 0 and one stderr line"; else fail "unusable plan-checkoff: exit 0 and one stderr line (rc=$rc err=$err)"; fi

# --- 14. hooks.json registers the hook under TaskCompleted via run-hook.cmd ---
if node -e '
const h = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).hooks;
const entries = (h.TaskCompleted || []).flatMap(e => e.hooks || []);
const ok = entries.some(x => x.type === "command" && /run-hook\.cmd" task-checkoff$/.test(x.command) && x.shell === "bash");
process.exit(ok ? 0 : 1);
' "$REPO_ROOT/hooks/hooks.json"; then pass "hooks.json registers TaskCompleted -> run-hook.cmd task-checkoff"; else fail "hooks.json registers TaskCompleted -> run-hook.cmd task-checkoff"; fi

# --- 15. run-hook.cmd dispatches to the hook ---
r=$(new_repo); activate "$r"
errf=$(mktemp)
payload='{"cwd":"'"$r"'","task_subject":"Task 1: First thing"}'
out=$(printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$REPO_ROOT/hooks/run-hook.cmd" task-checkoff 2>"$errf"); rc=$?; rm -f "$errf"
if [ "$rc" = "0" ] && [ "$(boxes_checked "$(plan_of "$r")")" = "2" ]; then pass "run-hook.cmd task-checkoff reaches the hook"; else fail "run-hook.cmd task-checkoff reaches the hook (rc=$rc)"; fi

# --- 16. run-hook.cmd dispatches a refusal too: rc=2, missing on stderr ---
rm "$r/src/alpha.txt"
errf=$(mktemp)
payload='{"cwd":"'"$r"'","task_subject":"Task 1: First thing"}'
out=$(printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$REPO_ROOT/hooks/run-hook.cmd" task-checkoff 2>"$errf"); rc=$?; err=$(cat "$errf"); rm -f "$errf"
if [ "$rc" = "2" ] && printf '%s' "$err" | grep -q 'missing: src/alpha.txt'; then pass "run-hook.cmd dispatches a refusal too"; else fail "run-hook.cmd dispatches a refusal too (rc=$rc err=$err)"; fi

echo ""
if [ "$failures" -eq 0 ]; then echo "All task-checkoff hook tests passed"; exit 0; fi
echo "$failures task-checkoff hook test(s) failed"; exit 1
