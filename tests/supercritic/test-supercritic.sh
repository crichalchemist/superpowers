#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE="$REPO_ROOT/skills/brainstorming/scripts/supercritic.sh"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

assert_contains() {
  if printf '%s' "$1" | grep -Fq -- "$2"; then pass "$3"
  else fail "$3"; echo "    expected to find: $2"; echo "    in: $1"; fi
}
assert_status() {
  # $1 actual rc, $2 expected rc, $3 description
  if [ "$1" -eq "$2" ]; then pass "$3"
  else fail "$3"; echo "    expected exit $2, got $1"; fi
}

# Stub CLI: echoes a marker plus everything it received as args, and brackets
# any stdin it sees so "empty" is distinguishable (proves the engine closes stdin).
cat >"$TEST_ROOT/echo-cli" <<'STUB'
#!/usr/bin/env bash
echo "REVIEW_MARKER"
echo "ARGS:$*"
echo "STDIN:[$(cat)]"
STUB
chmod +x "$TEST_ROOT/echo-cli"

# Stub CLI: sleeps forever (timeout test).
cat >"$TEST_ROOT/sleep-cli" <<'STUB'
#!/usr/bin/env bash
sleep 30
STUB
chmod +x "$TEST_ROOT/sleep-cli"

# Stub CLI: exits non-zero (fail-loud test).
cat >"$TEST_ROOT/fail-cli" <<'STUB'
#!/usr/bin/env bash
exit 3
STUB
chmod +x "$TEST_ROOT/fail-cli"

# Stub CLI: exits 0 with no output (empty-review test).
cat >"$TEST_ROOT/silent-cli" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$TEST_ROOT/silent-cli"

echo "supercritic engine tests"

# --- happy path: prints the review, passes focus+content through ---
conf="$TEST_ROOT/ok.conf"
cat >"$conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/echo-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=10
CONF
out=$(printf 'hello-artifact' | SUPERCRITIC_CONF="$conf" "$ENGINE" "MY_FOCUS" - 2>&1) && rc=0 || rc=$?
assert_status "$rc" 0 "happy path exits 0"
assert_contains "$out" "REVIEW_MARKER" "happy path prints CLI output"
assert_contains "$out" "MY_FOCUS" "focus reaches the CLI prompt"
assert_contains "$out" "hello-artifact" "piped content reaches the CLI prompt"
# The CLI's own stdin must be empty — engine closes it with </dev/null. The
# bracketed marker is "STDIN:[]" only when nothing leaked through:
assert_contains "$out" "STDIN:[]" "engine closes the CLI's stdin (no leakage)"

# --- missing conf: fail loud, exit 1 ---
out=$(SUPERCRITIC_CONF="$TEST_ROOT/nope.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "missing conf exits 1"
assert_contains "$out" "no config" "missing conf message"

# --- disabled conf: skip with exit 1 ---
cat >"$TEST_ROOT/dis.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/echo-cli")
SUPERCRITIC_ENABLED=0
SUPERCRITIC_VERIFIED=1
CONF
out=$(SUPERCRITIC_CONF="$TEST_ROOT/dis.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "disabled conf exits 1"
assert_contains "$out" "disabled" "disabled conf message"

# --- CLI fails: surface non-zero ---
cat >"$TEST_ROOT/fail.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/fail-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=10
CONF
out=$(SUPERCRITIC_CONF="$TEST_ROOT/fail.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "failing CLI exits 1"
assert_contains "$out" "exit 3" "failing CLI reports its exit code"

# --- timeout: fail loud and FAST ---
cat >"$TEST_ROOT/slow.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/sleep-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=1
CONF
start=$(date +%s)
out=$(SUPERCRITIC_CONF="$TEST_ROOT/slow.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
elapsed=$(( $(date +%s) - start ))
assert_status "$rc" 1 "timeout exits 1"
assert_contains "$out" "timed out" "timeout message"
if [ "$elapsed" -le 5 ]; then pass "timeout fires fast (<=5s)"; else fail "timeout too slow (${elapsed}s)"; fi

# --- unverified conf: fail loud, exit 1 ---
cat >"$TEST_ROOT/unverified.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/echo-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=0
CONF
out=$(SUPERCRITIC_CONF="$TEST_ROOT/unverified.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "unverified conf exits 1"
assert_contains "$out" "not verified" "unverified conf message"

# --- setup lifecycle: SUPERCRITIC_SMOKE=1 bypasses ONLY the verified gate ---
# (setup smoke-tests through the engine BEFORE it can honestly set VERIFIED=1)
out=$(printf 'smoke' | SUPERCRITIC_CONF="$TEST_ROOT/unverified.conf" SUPERCRITIC_SMOKE=1 "$ENGINE" "smoke" - 2>&1) && rc=0 || rc=$?
assert_status "$rc" 0 "SUPERCRITIC_SMOKE=1 lets the smoke test run against an unverified conf"
assert_contains "$out" "REVIEW_MARKER" "smoke run reaches the CLI"

# --- SUPERCRITIC_SMOKE must not override the enabled gate ---
out=$(SUPERCRITIC_CONF="$TEST_ROOT/dis.conf" SUPERCRITIC_SMOKE=1 "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "SUPERCRITIC_SMOKE=1 still respects SUPERCRITIC_ENABLED=0"
assert_contains "$out" "disabled" "smoke-on-disabled message"

# --- empty SUPERCRITIC_CMD: fail loud, exit 1 ---
cat >"$TEST_ROOT/emptycmd.conf" <<CONF
SUPERCRITIC_CMD=()
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
CONF
out=$(SUPERCRITIC_CONF="$TEST_ROOT/emptycmd.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "empty SUPERCRITIC_CMD exits 1"
assert_contains "$out" "SUPERCRITIC_CMD" "empty cmd message mentions SUPERCRITIC_CMD"

# --- missing file: fail loud, exit 2 ---
cat >"$TEST_ROOT/ok2.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/echo-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=10
CONF
out=$(SUPERCRITIC_CONF="$TEST_ROOT/ok2.conf" "$ENGINE" "f" "$TEST_ROOT/does-not-exist.txt" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 2 "missing file exits 2"
assert_contains "$out" "no such file" "missing file message"

# --- git-tracked conf: refuse to source (hostile-clone ACE guard) ---
# A conf committed to a repo would execute attacker bash on first consume-hook
# run. Staging is enough for git ls-files to consider it tracked.
mkdir -p "$TEST_ROOT/hostile-repo/.superpowers"
git -C "$TEST_ROOT/hostile-repo" init -q
cat >"$TEST_ROOT/hostile-repo/.superpowers/supercritic.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/echo-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
CONF
git -C "$TEST_ROOT/hostile-repo" add .superpowers/supercritic.conf
out=$(cd "$TEST_ROOT/hostile-repo" && "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "tracked conf exits 1"
assert_contains "$out" "tracked by git" "tracked conf refusal message"

# --- untracked conf inside a git repo: normal operation ---
mkdir -p "$TEST_ROOT/clean-repo/.superpowers"
git -C "$TEST_ROOT/clean-repo" init -q
cat >"$TEST_ROOT/clean-repo/.superpowers/supercritic.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/echo-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=10
CONF
out=$(cd "$TEST_ROOT/clean-repo" && printf 'x' | "$ENGINE" "f" - 2>&1) && rc=0 || rc=$?
assert_status "$rc" 0 "untracked conf in a git repo works"
assert_contains "$out" "REVIEW_MARKER" "untracked-conf run prints CLI output"

# --- oversize content: refuse before exec (single-argv ~128 KiB cap on Linux) ---
out=$(head -c 120000 /dev/zero | tr '\0' 'a' | SUPERCRITIC_CONF="$TEST_ROOT/ok2.conf" "$ENGINE" "f" - 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "oversize content exits 1"
assert_contains "$out" "too large" "oversize content message"

# --- CLI exits 0 with no output: fail loud, not silent success ---
cat >"$TEST_ROOT/silent.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/silent-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=10
CONF
out=$(SUPERCRITIC_CONF="$TEST_ROOT/silent.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "empty CLI output exits 1"
assert_contains "$out" "no output" "empty CLI output message"

if [ "$FAILURES" -gt 0 ]; then echo "$FAILURES supercritic engine test(s) failed"; exit 1; fi
echo "All supercritic engine tests passed"
