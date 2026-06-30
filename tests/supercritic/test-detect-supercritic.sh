#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DETECT="$REPO_ROOT/skills/brainstorming/scripts/detect-supercritic.sh"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
assert_contains() {
  if printf '%s' "$1" | grep -Fq -- "$2"; then pass "$3"
  else fail "$3"; echo "    expected: $2"; echo "    in: $1"; fi
}
assert_not_contains() {
  if printf '%s' "$1" | grep -Fq -- "$2"; then fail "$3"; echo "    did not expect: $2"
  else pass "$3"; fi
}

# Fake PATH with only stub CLIs present.
mkdir -p "$TEST_ROOT/bin"
printf '#!/usr/bin/env bash\necho stub\n' >"$TEST_ROOT/bin/agy"
printf '#!/usr/bin/env bash\necho stub\n' >"$TEST_ROOT/bin/codex"
printf '#!/usr/bin/env bash\necho stub\n' >"$TEST_ROOT/bin/gemini"
chmod +x "$TEST_ROOT/bin/agy" "$TEST_ROOT/bin/codex" "$TEST_ROOT/bin/gemini"

echo "detect-supercritic tests"

# Note: needles with tabs use $'...\t...' so the literal tab survives copy-paste.
# $BASH is the running interpreter's absolute path — avoids PATH lookup for bash itself.
out=$(PATH="$TEST_ROOT/bin" CLAUDE_PLUGIN_ROOT=/x CURSOR_PLUGIN_ROOT='' COPILOT_CLI='' \
  "$BASH" "$DETECT" 2>&1)
assert_contains "$out" $'agy\t' "lists installed agy"
assert_contains "$out" "codex" "lists installed codex"
assert_not_contains "$out" "cursor-agent" "omits not-installed cursor-agent"
assert_contains "$out" $'harness\tclaude-code' "detects claude-code harness"

out=$(PATH="$TEST_ROOT/bin" CLAUDE_PLUGIN_ROOT='' CURSOR_PLUGIN_ROOT=/y COPILOT_CLI='' \
  "$BASH" "$DETECT" 2>&1)
assert_contains "$out" $'harness\tcursor' "cursor env wins"

out=$(PATH="$TEST_ROOT/bin" CLAUDE_PLUGIN_ROOT='' CURSOR_PLUGIN_ROOT='' COPILOT_CLI=/x \
  "$BASH" "$DETECT" 2>&1)
assert_contains "$out" $'harness\tcopilot' "detects copilot harness"

out=$(PATH="$TEST_ROOT/bin" CLAUDE_PLUGIN_ROOT='' CURSOR_PLUGIN_ROOT='' COPILOT_CLI='' \
  "$BASH" "$DETECT" 2>&1)
assert_contains "$out" $'harness\tunknown' "detects unknown harness"
assert_contains "$out" "EOLed-upstream(#1846)" "gemini note present"

if [ "$FAILURES" -gt 0 ]; then echo "$FAILURES detect test(s) failed"; exit 1; fi
echo "All detect-supercritic tests passed"
