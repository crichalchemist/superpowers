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
git -C "$r" add -A >/dev/null; git -C "$r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -qm init
( cd "$r" && "$ACTIVE" set docs/superpowers/plans/demo.md >/dev/null )
if [ -z "$(git -C "$r" status --porcelain)" ]; then pass "marker is git-ignored"; else fail "marker is git-ignored ($(git -C "$r" status --porcelain | tr '\n' ' '))"; fi

# --- 7. usage ---
( cd "$r" && "$ACTIVE" >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "2" ]; then pass "no arguments is a usage error, exit 2"; else fail "no arguments is a usage error, exit 2 (rc=$rc)"; fi

# --- 8. clear outside a git repository is silent and exits 0 ---
d=$(mktemp -d)
err=$(cd "$d" && GIT_CEILING_DIRECTORIES="$d" "$ACTIVE" clear 2>&1 >/dev/null); rc=$?
if [ "$rc" = "0" ] && [ -z "$err" ]; then pass "clear outside a git repository exits 0 with empty stderr"; else fail "clear outside a git repository exits 0 with empty stderr (rc=$rc err=$err)"; fi

echo ""
if [ "$failures" -eq 0 ]; then echo "All active-plan tests passed"; exit 0; fi
echo "$failures active-plan test(s) failed"; exit 1
