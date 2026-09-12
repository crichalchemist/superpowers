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
