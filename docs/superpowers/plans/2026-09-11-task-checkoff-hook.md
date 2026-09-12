# Task-Completion Check-off Hook — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When an agent marks a plan task complete with the Task tools, a `TaskCompleted` hook runs `plan-checkoff --done N` for it, and a refused check-off blocks the completion.

**Architecture:** Two new bash scripts and one manifest entry. `scripts/active-plan` writes a marker naming the plan a session is executing. `hooks/task-checkoff` reads the `TaskCompleted` event, matches `task_subject` against the plan's `### Task N: <name>` heading, calls `plan-checkoff --done N`, and exits 2 on a refusal so Claude Code keeps the task open and shows the agent why. Both executing skills gain the marker calls and the exact-subject convention. `plan-checkoff` itself does not change.

**Tech Stack:** bash 3.2+, sed, awk, git. Zero new dependencies; `node` appears only in tests, as `tests/hooks/test-session-start.sh` already does.

**Spec:** `docs/superpowers/specs/2026-09-11-todo-checkoff-hook-design.md` (revision 2). It builds on `docs/superpowers/specs/2026-09-11-plan-checkoff-verify-design.md`; that script's contract stands unchanged.

**Branch and base:** cut the build branch from `develop` once the `plan-checkoff` branch (fork PR #2) has been merged into it, so `scripts/plan-checkoff --done` and the skill anchors named below exist. Every line number in this plan is taken from `plan-checkoff` at `cbb27ac`; the setup step re-checks them.

## Global Constraints

- **The hook is additive.** Both skills keep their `plan-checkoff --done N` prose. The hook adds no verification and no prose of its own; it relays `plan-checkoff`'s lines.
- **Only a refusal blocks.** The hook exits 2 only when `plan-checkoff` exits 4. Any other problem (no marker, unparsable input, missing script, exit 2 or 3 from the script) exits 0, at most one stderr line, and the completion proceeds.
- **Whole-subject match.** A completion qualifies only when `task_subject` is `Task N: <name>` and `<name>` equals the plan's unfenced `### Task N: <name>` heading text, compared case-insensitively with surrounding whitespace trimmed and internal runs of whitespace collapsed to one space.
- **Marker path:** `<repo-root>/.superpowers/sdd/active-plan`, one line, the plan's absolute path. Root is `git rev-parse --show-toplevel` from the plan's directory (`set`) or from the caller's directory (`clear`, `show`).
- **Hook input fields used:** `cwd` and `task_subject` from the `TaskCompleted` stdin JSON. Extracted with sed; `\"` and `\\` are unescaped; anything else that fails to parse means silent exit 0.
- **`plan-checkoff` location:** `${CLAUDE_PLUGIN_ROOT}/skills/subagent-driven-development/scripts/plan-checkoff`, falling back to the hook's own repository when the variable is unset (tests set it explicitly).
- **Task tools gate:** the skills say Claude 5 models need `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in a settings `env` block. No skill text detects the harness or branches on it.
- **Zero dependencies in shipped scripts:** no `jq`, no `node`, no python. Tests may use `node` for JSON assertions (existing precedent).
- **House style:** `set -euo pipefail` where the script never needs a non-zero status from a child, `set -uo pipefail` where it does; quoted expansions; header usage comment; `shellcheck --severity=warning` clean with no `shellcheck disable` directives. Test idiom is `if …; then pass "…"; else fail "…"; fi`, throwaway git repos from a `new_repo` helper, no host environment leakage (no `:$PATH` appends).
- **Skill prose:** only the sentences named in Task 4 change. No Red Flags table, rationalization list, or "human partner" language is touched.
- **Commits:** one per task, conventional subject, no `Co-Authored-By` or agent trailers. Do not push.
- **Teardown (fork rule, `.claude/CLAUDE.md`):** archive this plan's ledger and reviews under `docs/superpowers/ledgers/2026-09-11-task-checkoff-hook/` before the workspace is deleted.

---

### Task 1: Probe the harness contract and keep the probe

The spec's "Verified harness contract" section was measured by hand on 2026-09-11. This task turns that probe into a committed script so the contract can be re-checked on any Claude Code version, and runs it once before anything depends on it.

**Files:**
- Create: `tests/hooks/probe-task-completed.sh`

**Interfaces:**
- Produces: a manual probe (not part of any suite) whose exit 0 means: the session had the Task tools, the `TaskCompleted` hook fired with `task_subject` in its stdin, and exit 2 left the task `pending`. Prints the recorded stdin and the model's report.

- [x] **Step 1: Write the probe**

```bash
#!/usr/bin/env bash
# Manual probe of the Claude Code TaskCompleted hook contract. Not part of any
# test suite: it starts a real headless Claude Code session and costs tokens.
#
# It builds a scratch project whose project settings enable the Task tools and
# register a TaskCompleted hook that (a) records its stdin and (b) exits 2 for
# any task whose subject starts with "Task 1". Then it asks the model to create
# two tasks and complete both, and checks what happened.
#
# Exit 0: contract holds (Task tools present, hook fired with task_subject,
#         exit 2 kept Task 1 pending). Exit 1: something differs; read the output.
#
# Usage: tests/hooks/probe-task-completed.sh [model]   (default model: sonnet)
set -uo pipefail

model=${1:-sonnet}
command -v claude >/dev/null || { echo "probe: claude CLI not on PATH" >&2; exit 1; }

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/.claude" "$scratch/.hook-probe"
git -C "$scratch" init -q

cat > "$scratch/.claude/hook-probe.sh" <<'HOOK'
#!/usr/bin/env bash
set -u
dir="$(cd "$(dirname "$0")/.." && pwd)/.hook-probe"
input=$(cat)
n=$(find "$dir" -name 'in-*.json' | wc -l | tr -d ' ')
printf '%s\n' "$input" > "$dir/in-$((n + 1)).json"
if printf '%s' "$input" | grep -q '"task_subject": *"Task 1'; then
  printf 'PROBE-REFUSAL: Task 1: missing: src/x.sh — not flipped\n' >&2
  exit 2
fi
exit 0
HOOK
chmod +x "$scratch/.claude/hook-probe.sh"

cat > "$scratch/.claude/settings.json" <<'JSON'
{
  "env": { "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1" },
  "hooks": {
    "TaskCompleted": [
      { "hooks": [ { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR/.claude/hook-probe.sh\"" } ] }
    ]
  }
}
JSON

prompt='Do this exactly, in order. (1) State which of TaskCreate, TaskUpdate, TaskList, TaskGet, TodoWrite you have. (2) Create two tasks with TaskCreate: subject "Task 1: greet.sh" and subject "Task 2: shout.sh". (3) TaskUpdate "Task 2: shout.sh" to status completed. (4) TaskUpdate "Task 1: greet.sh" to status completed. (5) Call TaskList. (6) Report in exactly this shape, quoting verbatim any feedback text: TOOLS: ... AFTER UPDATE 2: ... AFTER UPDATE 1: ... TASKLIST: ...'

report=$(cd "$scratch" && claude -p --model "$model" "$prompt" 2>&1)
status=0

echo "=== model report ==="
printf '%s\n' "$report"
echo "=== hook stdin ==="
cat "$scratch"/.hook-probe/in-*.json 2>/dev/null || echo "(no hook input recorded)"
echo "=== checks ==="

check() { if eval "$2"; then echo "  [PASS] $1"; else echo "  [FAIL] $1"; status=1; fi; }
check "session had TaskCreate"            'printf "%s" "$report" | grep -q "TaskCreate"'
check "hook fired at least once"          'ls "$scratch"/.hook-probe/in-*.json >/dev/null 2>&1'
check "stdin carries task_subject"        'cat "$scratch"/.hook-probe/in-*.json | grep -q "\"task_subject\""'
check "stdin carries cwd"                 'cat "$scratch"/.hook-probe/in-*.json | grep -q "\"cwd\""'
check "exit 2 text reached the model"     'printf "%s" "$report" | grep -q "PROBE-REFUSAL"'
check "blocked task stayed pending"       'printf "%s" "$report" | grep -Eq "\[pending\][^#]*Task 1|Task 1[^#]*pending"'
check "allowed task completed"            'printf "%s" "$report" | grep -Eq "\[completed\][^#]*Task 2|Task 2[^#]*completed"'
exit "$status"
```

- [x] **Step 2: Make it executable and lint it**

Run: `chmod +x tests/hooks/probe-task-completed.sh && shellcheck --severity=warning tests/hooks/probe-task-completed.sh`
Expected: no output.

- [x] **Step 3: Run it once against the installed harness**

Run: `tests/hooks/probe-task-completed.sh`
Expected: seven `[PASS]` lines, exit 0. Copy the `=== hook stdin ===` block into your report. If any check fails, stop: the spec's contract section is wrong for this version, and the controller must rule before Task 3 is built.

- [x] **Step 4: Commit**

```bash
git add tests/hooks/probe-task-completed.sh
git commit -m "test(hooks): manual probe of the TaskCompleted hook contract"
```

---

### Task 2: `active-plan` marker script

**Files:**
- Create: `skills/subagent-driven-development/scripts/active-plan`
- Create: `tests/claude-code/test-active-plan.sh`
- Modify: `tests/claude-code/run-skill-tests.sh:78-83`

**Interfaces:**
- Produces: `active-plan set PLAN_FILE` (writes `<root>/.superpowers/sdd/active-plan`, prints the absolute plan path, exit 0; exit 2 on a missing plan or outside git), `active-plan clear` (removes the marker, exit 0 always), `active-plan show` (prints the marker's line, exit 0; exit 1 with no output when absent). Root for `set` is the repository containing the plan; for `clear`/`show` the repository containing the caller's directory. Task 3's hook reads the marker file directly.

- [x] **Step 1: Write the failing tests**

Create `tests/claude-code/test-active-plan.sh`:

```bash
#!/usr/bin/env bash
# Tests for active-plan: the marker that names the plan a session is executing.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/../../skills/subagent-driven-development/scripts" && pwd)"
ACTIVE="$SCRIPT_DIR/active-plan"

failures=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }

echo "active-plan tests"

# Each test builds a throwaway git repo so `git rev-parse` works.
new_repo() {
  local d; d=$(mktemp -d)
  git -C "$d" init -q
  mkdir -p "$d/docs/superpowers/plans"
  printf '# Demo\n\n### Task 1: First\n' > "$d/docs/superpowers/plans/demo.md"
  echo "$d"
}

# --- 1. set writes the absolute path and prints it ---
r=$(new_repo)
out=$(cd "$r" && "$ACTIVE" set docs/superpowers/plans/demo.md); rc=$?
marker="$r/.superpowers/sdd/active-plan"
if [ "$rc" = "0" ] && [ -f "$marker" ] && [ "$(cat "$marker")" = "$r/docs/superpowers/plans/demo.md" ]; then pass "set writes the absolute plan path to the marker"; else fail "set writes the absolute plan path to the marker (rc=$rc)"; fi
if [ "$out" = "$r/docs/superpowers/plans/demo.md" ]; then pass "set prints the absolute plan path"; else fail "set prints the absolute plan path (got: $out)"; fi

# --- 2. set from another directory resolves the plan's own repo ---
r=$(new_repo); other=$(mktemp -d)
( cd "$other" && "$ACTIVE" set "$r/docs/superpowers/plans/demo.md" >/dev/null 2>&1 )
if [ -f "$r/.superpowers/sdd/active-plan" ] && [ ! -e "$other/.superpowers" ]; then pass "set resolves the root from the plan, not the caller"; else fail "set resolves the root from the plan, not the caller"; fi

# --- 3. set on a missing plan exits 2 ---
r=$(new_repo)
( cd "$r" && "$ACTIVE" set docs/superpowers/plans/nope.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "2" ] && [ ! -e "$r/.superpowers/sdd/active-plan" ]; then pass "set on a missing plan exits 2 and writes nothing"; else fail "set on a missing plan exits 2 and writes nothing (rc=$rc)"; fi

# --- 4. show: exit 1 when absent, prints the path once set ---
r=$(new_repo)
out=$(cd "$r" && "$ACTIVE" show 2>/dev/null); rc=$?
if [ "$rc" = "1" ] && [ -z "$out" ]; then pass "show exits 1 with no marker"; else fail "show exits 1 with no marker (rc=$rc out=$out)"; fi
( cd "$r" && "$ACTIVE" set docs/superpowers/plans/demo.md >/dev/null )
out=$(cd "$r" && "$ACTIVE" show); rc=$?
if [ "$rc" = "0" ] && [ "$out" = "$r/docs/superpowers/plans/demo.md" ]; then pass "show prints the marker once set"; else fail "show prints the marker once set (rc=$rc out=$out)"; fi

# --- 5. clear removes the marker and is idempotent ---
( cd "$r" && "$ACTIVE" clear ); rc1=$?
( cd "$r" && "$ACTIVE" clear ); rc2=$?
if [ "$rc1" = "0" ] && [ "$rc2" = "0" ] && [ ! -e "$r/.superpowers/sdd/active-plan" ]; then pass "clear removes the marker and is idempotent"; else fail "clear removes the marker and is idempotent (rc=$rc1/$rc2)"; fi

# --- 6. the marker never shows in git status ---
r=$(new_repo)
git -C "$r" add -A >/dev/null; git -C "$r" -c user.email=t@t -c user.name=t commit -qm init
( cd "$r" && "$ACTIVE" set docs/superpowers/plans/demo.md >/dev/null )
if [ -z "$(git -C "$r" status --porcelain)" ]; then pass "marker is git-ignored"; else fail "marker is git-ignored ($(git -C "$r" status --porcelain | tr '\n' ' '))"; fi

# --- 7. usage ---
( cd "$r" && "$ACTIVE" >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "2" ]; then pass "no arguments is a usage error, exit 2"; else fail "no arguments is a usage error, exit 2 (rc=$rc)"; fi

echo ""
if [ "$failures" -eq 0 ]; then echo "All active-plan tests passed"; exit 0; fi
echo "$failures active-plan test(s) failed"; exit 1
```

- [x] **Step 2: Run it to verify it fails**

Run: `bash tests/claude-code/test-active-plan.sh`
Expected: every assertion `[FAIL]` (the script does not exist; each invocation exits 127), final line `9 active-plan test(s) failed`, exit 1.

- [x] **Step 3: Write the script**

Create `skills/subagent-driven-development/scripts/active-plan`:

```bash
#!/usr/bin/env bash
# Name the plan a session is executing, so the task-completion check-off hook
# (hooks/task-checkoff) knows which plan a completed "Task N: <name>" belongs to.
#
#   active-plan set PLAN_FILE   write <repo-root>/.superpowers/sdd/active-plan, print the absolute path
#   active-plan clear           remove the marker; silent if absent
#   active-plan show            print the marker's path; exit 1 if none
#
# One marker per repository root: two plans executing in the same working tree
# race on it and the last `set` wins — the same limit the SDD ledger has.
# The marker lives beside the SDD workspaces, under the self-ignoring
# .superpowers/sdd/.gitignore that sdd-workspace also writes, so it never
# appears in `git status`.
#
# Exit codes: 0 ok; 1 `show` with no marker; 2 usage, missing plan, or not in a git repository.
set -euo pipefail

usage() { echo "usage: active-plan set PLAN_FILE | clear | show" >&2; exit 2; }
die() { echo "active-plan: $1" >&2; exit 2; }

# root DIR -> repository root containing DIR
root() { git -C "$1" rev-parse --show-toplevel 2>/dev/null || die "$1 is not inside a git repository"; }

case "${1:-}" in
  set)
    [ $# -eq 2 ] || usage
    [ -f "$2" ] || die "no such plan file: $2"
    plan_dir=$(cd "$(dirname "$2")" && pwd)
    abs="$plan_dir/$(basename "$2")"
    base="$(root "$plan_dir")/.superpowers/sdd"
    mkdir -p "$base"
    printf '*\n' > "$base/.gitignore"
    printf '%s\n' "$abs" > "$base/active-plan"
    printf '%s\n' "$abs"
    ;;
  clear)
    [ $# -eq 1 ] || usage
    rm -f "$(root .)/.superpowers/sdd/active-plan"
    ;;
  show)
    [ $# -eq 1 ] || usage
    marker="$(root .)/.superpowers/sdd/active-plan"
    [ -f "$marker" ] || exit 1
    cat "$marker"
    ;;
  *) usage ;;
esac
```

Then: `chmod +x skills/subagent-driven-development/scripts/active-plan`

- [x] **Step 4: Run the tests to verify they pass**

Run: `bash tests/claude-code/test-active-plan.sh`
Expected: 9 `[PASS]`, `All active-plan tests passed`, exit 0.

- [x] **Step 5: Lint**

Run: `shellcheck --severity=warning skills/subagent-driven-development/scripts/active-plan tests/claude-code/test-active-plan.sh`
Expected: no output.

- [x] **Step 6: Wire the test into the runner**

In `tests/claude-code/run-skill-tests.sh`, the `tests=(…)` array (lines 78–83) gains one entry directly after `"test-plan-checkoff.sh"`:

```bash
    "test-active-plan.sh"
```

- [x] **Step 7: Commit**

```bash
git add skills/subagent-driven-development/scripts/active-plan tests/claude-code/test-active-plan.sh tests/claude-code/run-skill-tests.sh
git commit -m "feat(sdd): active-plan marker names the plan a session is executing"
```

---

### Task 3: `task-checkoff` hook and manifest entry

**Files:**
- Create: `hooks/task-checkoff`
- Create: `tests/hooks/test-task-checkoff.sh`
- Modify: `hooks/hooks.json`

**Interfaces:**
- Consumes: the marker file from Task 2 (`<root>/.superpowers/sdd/active-plan`, one absolute path); `plan-checkoff --done N PLAN` and its exit codes (0 flipped or nothing to flip, 2 usage, 3 workspace, 4 refused) and its stderr lines (`plan-checkoff: Task N: missing: <paths> — not flipped`, `plan-checkoff: Task N: unverified: lists no files — not flipped`).
- Produces: `hooks/task-checkoff`, reading the `TaskCompleted` JSON on stdin; exit 2 with the refusal lines on stderr when the check-off is refused; exit 0 otherwise. Registered under `TaskCompleted` in `hooks/hooks.json`.

- [x] **Step 1: Write the failing tests**

Create `tests/hooks/test-task-checkoff.sh`:

```bash
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

boxes_checked() { grep -c '^\s*- \[x\]' "$1" || true; }
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

echo ""
if [ "$failures" -eq 0 ]; then echo "All task-checkoff hook tests passed"; exit 0; fi
echo "$failures task-checkoff hook test(s) failed"; exit 1
```

- [x] **Step 2: Run it to verify it fails**

Run: `bash tests/hooks/test-task-checkoff.sh`
Expected: every assertion `[FAIL]`. With no hook file, `bash "$HOOK"` exits 127 and prints "No such file" on stderr, so even the "silent exit 0" cases fail; the manifest assertion fails on the missing entry. Final line `15 task-checkoff hook test(s) failed`, exit 1.

- [x] **Step 3: Write the hook**

Create `hooks/task-checkoff`:

```bash
#!/usr/bin/env bash
# TaskCompleted hook: when the completed task's subject is a plan heading,
# "Task N: <name>", run plan-checkoff --done N for it. A refused check-off
# (exit 4: a Files: path is missing, or the task lists none) exits 2, which
# makes Claude Code keep the task open and show the refusal to the model.
#
# Everything else exits 0 and lets the completion proceed: no marker, an
# input we cannot parse, a subject that is not a plan heading, a heading whose
# name differs, an already-ticked task, or a broken plan-checkoff. The hook
# never holds a task hostage for a reason the agent cannot fix.
#
# Input: the TaskCompleted JSON on stdin; only "cwd" and "task_subject" are read.
# The plan comes from <repo-root>/.superpowers/sdd/active-plan (see
# skills/subagent-driven-development/scripts/active-plan).
set -uo pipefail

input=$(cat)

# field NAME -> the string value of "NAME":"..." with \" and \\ unescaped; empty if absent.
field() {
  printf '%s' "$input" \
    | sed -n 's/.*"'"$1"'":"\(\([^"\\]\|\\.\)*\)".*/\1/p' \
    | head -n 1 \
    | sed 's/\\"/"/g; s/\\\\/\\/g'
}

cwd=$(field cwd)
subject=$(field task_subject)
[ -n "$cwd" ] && [ -n "$subject" ] || exit 0

root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
marker="$root/.superpowers/sdd/active-plan"
[ -f "$marker" ] || exit 0
plan=$(head -n 1 "$marker")
[ -f "$plan" ] || exit 0

case "$subject" in
  Task\ [0-9]*|task\ [0-9]*) ;;
  *) exit 0 ;;
esac
n=$(printf '%s' "$subject" | sed -n 's/^[Tt]ask \([0-9][0-9]*\):\{0,1\}.*/\1/p')
name=$(printf '%s' "$subject" | sed -n 's/^[Tt]ask [0-9][0-9]*:\{0,1\}[[:space:]]*\(.*\)$/\1/p')
[ -n "$n" ] || exit 0

# The plan's own heading text for Task N, unfenced, fence toggle as in plan-checkoff.
heading=$(awk -v n="$n" '
  /^```/ { infence = !infence; next }
  !infence && $0 ~ ("^#+[ \t]+Task[ \t]+" n "([^0-9]|$)") {
    sub(/^#+[ \t]+Task[ \t]+[0-9]+:?[ \t]*/, ""); print; exit
  }
' "$plan")
[ -n "$heading" ] || exit 0

# normalise: lower-case, trim, collapse internal whitespace.
norm() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g'
}
[ "$(norm "$name")" = "$(norm "$heading")" ] || exit 0

plugin_root=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
checkoff="$plugin_root/skills/subagent-driven-development/scripts/plan-checkoff"
if [ ! -x "$checkoff" ]; then
  echo "task-checkoff: plan-checkoff not executable at $checkoff" >&2
  exit 0
fi

out=$("$checkoff" --done "$n" "$plan" 2>&1); rc=$?
case "$rc" in
  0) exit 0 ;;
  4)
    refusal=$(printf '%s\n' "$out" | grep 'not flipped' || printf '%s\n' "$out")
    printf '%s\n' "$refusal" >&2
    exit 2 ;;
  *)
    echo "task-checkoff: plan-checkoff exited $rc for Task $n in $plan" >&2
    exit 0 ;;
esac
```

Then: `chmod +x hooks/task-checkoff`

- [x] **Step 4: Register the hook**

Replace `hooks/hooks.json` with:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "shell": "bash",
            "async": false
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" task-checkoff",
            "shell": "bash"
          }
        ]
      }
    ]
  }
}
```

`hooks/hooks-cursor.json` is not touched.

- [x] **Step 5: Run the tests to verify they pass**

Run: `bash tests/hooks/test-task-checkoff.sh`
Expected: 15 `[PASS]`, `All task-checkoff hook tests passed`, exit 0.

- [x] **Step 6: Lint and confirm the existing suites still pass**

Run: `shellcheck --severity=warning hooks/task-checkoff tests/hooks/test-task-checkoff.sh`
Expected: no output.

Run: `bash tests/hooks/test-session-start.sh | tail -1 && bash tests/claude-code/test-plan-checkoff.sh | tail -1`
Expected: both suites report all passed (the check-off suite stays at 52).

- [x] **Step 7: Commit**

```bash
git add hooks/task-checkoff hooks/hooks.json tests/hooks/test-task-checkoff.sh
git commit -m "feat(hooks): TaskCompleted hook checks off the matching plan task, blocks on refusal"
```

---

### Task 4: Skill edits

Eight sentences across two skills. Every anchor is quoted from `plan-checkoff` at `cbb27ac`; confirm each with `grep -n` before editing and stop if one is missing.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:137-139,160-161,445,486-487`
- Modify: `skills/executing-plans/SKILL.md:23,31-35,40-42`

**Interfaces:**
- Consumes: `scripts/active-plan set|clear` from Task 2; the hook's behaviour from Task 3 (a refused completion stays open and prints `missing:` or `unverified`).

- [x] **Step 1: Confirm the anchors**

Run:
```bash
grep -n 'scripts/sdd-workspace PLAN_FILE' skills/subagent-driven-development/SKILL.md
grep -n 'create a$' skills/subagent-driven-development/SKILL.md
grep -n 'Then mark the todo complete and move on' skills/subagent-driven-development/SKILL.md
grep -n 'Before deleting the workspace, run' skills/subagent-driven-development/SKILL.md
grep -n 'Create todos for the plan items and proceed' skills/executing-plans/SKILL.md
grep -n 'Mark as completed — the todo, and the plan file' skills/executing-plans/SKILL.md
grep -n 'plan-checkoff --verify PLAN_FILE' skills/executing-plans/SKILL.md
```
Expected: one hit each (the second one is the line ending "…note its context and Global Constraints, and create a", immediately before "todo per task").

- [x] **Step 2: Edit subagent-driven-development/SKILL.md**

(a) The Setup workspace bullet currently reads:

```
- Each plan owns a workspace: at skill start, run this skill's
  `scripts/sdd-workspace PLAN_FILE` — it prints the plan's git-ignored
  directory (`<repo-root>/.superpowers/sdd/<plan-basename>/`), home to
  every artifact for THIS plan: ledger, briefs, reports, review packages.
  Another plan's directory is never yours to read or write.
```

Append one sentence so it ends:

```
  Another plan's directory is never yours to read or write. Then run
  `scripts/active-plan set PLAN_FILE`, which names this plan to the
  task-completion check-off hook.
```

(b) The paragraph "Read the plan once, note its context and Global Constraints, and create a todo per task. If the plan names a Spec, read that too: …" becomes:

```
Read the plan once, note its context and Global Constraints, and create one
task per plan task with TaskCreate, subject exactly the plan's heading,
`Task N: <name>`, so the check-off hook can match it. (Claude 5 models need
`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in a settings `env` block for the Task
tools to exist.) If the plan names a Spec, read that too: the spec is the
```

The rest of the paragraph is unchanged.

(c) The sentence "Then mark the todo complete and move on. Never move to the next task while the review has open Critical/Important issues that are neither fixed nor parked-with-ruling at the cap." becomes:

```
Then mark the task complete and move on. On Claude Code the completion runs
`plan-checkoff --done N` through a hook; if the hook refuses, the task stays
open and the `missing:` or `unverified` line says why, whatever the review
said. Never move to the next task while the review has open
Critical/Important issues that are neither fixed nor parked-with-ruling at
the cap.
```

(d) The teardown sentence "Before deleting the workspace, run `scripts/plan-checkoff PLAN_FILE` one last time — deletion destroys the ledger, so this is the last moment the plan's checkboxes can be reconciled from it." becomes:

```
Before deleting the workspace, run `scripts/plan-checkoff PLAN_FILE` one last
time, then `scripts/active-plan clear` — deletion destroys the ledger, so
this is the last moment the plan's checkboxes can be reconciled from it.
```

- [x] **Step 3: Edit executing-plans/SKILL.md**

(a) Step 1 item 5, "5. If no concerns: Create todos for the plan items and proceed", becomes:

```
5. If no concerns: create one task per plan task with TaskCreate, subject
   exactly the plan's heading, `Task N: <name>`; run
   `../subagent-driven-development/scripts/active-plan set PLAN_FILE`; proceed.
   (Claude 5 models need `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in a settings
   `env` block for the Task tools to exist.)
```

(b) Step 2 item 4 currently reads:

```
4. Mark as completed — the todo, and the plan file: run
   `../subagent-driven-development/scripts/plan-checkoff --done N PLAN_FILE`
   (path relative to this skill's directory) for the task you just finished.
   Exit 4 means a path the task's `Files:` block names does not exist yet, or
   the task lists none: the task is not done — fix what is missing, then rerun.
```

It becomes:

```
4. Mark as completed — the task, and the plan file: run
   `../subagent-driven-development/scripts/plan-checkoff --done N PLAN_FILE`
   (path relative to this skill's directory) for the task you just finished.
   Exit 4 means a path the task's `Files:` block names does not exist yet, or
   the task lists none: the task is not done — fix what is missing, then rerun.
   Marking the task complete runs the same check-off through a hook on Claude
   Code; a refused completion means the task is not done.
```

(c) Step 3's first bullet currently reads:

```
- Run `../subagent-driven-development/scripts/plan-checkoff --verify PLAN_FILE`;
  a non-zero exit lists ticked tasks whose deliverables are missing — resolve
  them before going on.
```

It becomes:

```
- Run `../subagent-driven-development/scripts/plan-checkoff --verify PLAN_FILE`;
  a non-zero exit lists ticked tasks whose deliverables are missing — resolve
  them before going on. Then run `../subagent-driven-development/scripts/active-plan clear`
  and commit the plan file with the check-off.
```

- [x] **Step 4: Verify the edits are the whole diff**

Run: `git diff --stat`
Expected: exactly the two SKILL.md files.

Run: `git diff | grep -E '^[-+]' | grep -v '^[-+]{3}' | grep -ciE 'red flag|rationaliz|human partner'`
Expected: `0` (no protected content touched).

Run: `git diff -U0 skills/subagent-driven-development/SKILL.md | grep -c '^@@'`
Expected: `4` (four hunks, one per edit).

- [x] **Step 5: Run the skill and hook suites once more**

Run: `bash tests/hooks/test-task-checkoff.sh | tail -1 && bash tests/claude-code/test-active-plan.sh | tail -1 && bash tests/claude-code/test-plan-checkoff.sh | tail -1`
Expected: three "All … passed" lines.

- [x] **Step 6: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md skills/executing-plans/SKILL.md
git commit -m "feat(skills): name the active plan and the Task N subject so the check-off hook can match"
```

---

## After the build (controller, not a plan task)

The spec's eval (two cells per skill, `hook + both` and `hook alone`) runs after the final review is clean, with the same rig as `docs/superpowers/ledgers/2026-09-11-plan-checkoff-eval/` plus `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in each toy's committed project settings. Its record is archived beside this plan's ledger.
