#!/usr/bin/env bash
#
# supercritic.sh — opt-in, independent, read-only "supercritic" review via a
# user-chosen CLI. Generalizes the original agy-review.sh: models are partial to
# their own work, so a DIFFERENT model catches what the authoring model waves
# through. The standard "independent different-model voice" step in the
# superpowers flow — a second opinion alongside the in-house self-reviews.
#
# Usage:
#   scripts/supercritic.sh "<focus>" <file>           # review a file (spec, plan, doc)
#   <producer> | scripts/supercritic.sh "<focus>" -   # review piped text (e.g. a diff)
#
# Config: sources $SUPERCRITIC_CONF (default: ./.superpowers/supercritic.conf).
# Must set SUPERCRITIC_CMD as a bash array, e.g. SUPERCRITIC_CMD=(agy --print).
# May set SUPERCRITIC_ENABLED (1/0), SUPERCRITIC_VERIFIED (1/0),
# SUPERCRITIC_TIMEOUT (seconds, default 120), SUPERCRITIC_MODEL (informational).
# SUPERCRITIC_SMOKE=1 (env, never conf) bypasses only the VERIFIED gate so
# setup's smoke test can run through this engine before VERIFIED is set to 1.
#
# SAFETY INVARIANT (do not change): reviews go through inline content only — the
# CLI sees only the text we pass, so the review is read-only by construction. No
# repo-access or permission-skipping flags belong in SUPERCRITIC_CMD. `</dev/null`
# is REQUIRED — print-mode CLIs block waiting on stdin otherwise (observed with
# agy: hangs indefinitely). Every CLI call is timeout-guarded so a misconfigured
# CLI fails loud, never hangs.
set -euo pipefail

die() { echo "supercritic: $*" >&2; exit 1; }

if [ $# -lt 2 ]; then
  echo "usage: $0 \"<focus>\" <file|->" >&2
  exit 2
fi
focus=$1
src=$2

conf=${SUPERCRITIC_CONF:-.superpowers/supercritic.conf}
[ -f "$conf" ] || die "no config at $conf (run detect-supercritic.sh and configure first)"
# Sourcing executes the conf. A conf tracked by git could arrive in a hostile
# clone and run attacker bash the first time a consume hook fires. Legit confs
# are always untracked (setup step 5 gitignores .superpowers/), so refuse.
if command -v git >/dev/null 2>&1 && git ls-files --error-unmatch -- "$conf" >/dev/null 2>&1; then
  die "$conf is tracked by git — refusing to source it (a committed conf can execute arbitrary code; untrack it and gitignore .superpowers/)"
fi
# shellcheck source=/dev/null
. "$conf"

[ "${SUPERCRITIC_ENABLED:-0}" = "1" ] || die "supercritic disabled in $conf"
if [ "${SUPERCRITIC_SMOKE:-0}" != "1" ]; then
  [ "${SUPERCRITIC_VERIFIED:-0}" = "1" ] || die "supercritic not verified in $conf (smoke test never passed)"
fi
# SUPERCRITIC_CMD is set by the sourced conf above; shellcheck cannot follow the source.
# shellcheck disable=SC2154
if ! declare -p SUPERCRITIC_CMD >/dev/null 2>&1 || [ "${#SUPERCRITIC_CMD[@]}" -lt 1 ]; then
  die "SUPERCRITIC_CMD not set as a non-empty bash array in $conf"
fi
timeout_secs=${SUPERCRITIC_TIMEOUT:-120}

if [ "$src" = "-" ]; then
  content=$(cat)
else
  [ -f "$src" ] || { echo "supercritic: no such file: $src" >&2; exit 2; }
  content=$(cat "$src")
fi

# The prompt travels as ONE exec argument; Linux caps a single argument at
# ~128 KiB (MAX_ARG_STRLEN). Bound well below the cap and fail loud.
content_bytes=$(( $(printf '%s' "$content" | wc -c) ))
if [ "$content_bytes" -gt 100000 ]; then
  die "content too large (${content_bytes} bytes > 100000) — narrow the diff or split the review"
fi

prompt=$(cat <<EOF
You are doing a READ-ONLY review. Do not ask follow-up questions; produce the review directly.

Focus: ${focus}

Be critical, specific, and concrete; reference section names or quote the exact text you mean. Cover correctness, risks that would bite during implementation, edge cases, and testability. End with a one-line verdict: ready to proceed, or what must change first.

=== UNDER REVIEW ===
${content}
EOF
)

# Portable timeout: GNU timeout, gtimeout (macOS coreutils), or a bash fallback.
run_with_timeout() {
  local secs=$1; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout -k 5 "$secs" "$@" </dev/null
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout -k 5 "$secs" "$@" </dev/null
  else
    # Fallback: TERM hits the launched process. If a CLI forks a long-lived
    # grandchild, that child may outlive the kill — prefer real `timeout`/`gtimeout`.
    "$@" </dev/null &
    local pid=$!
    # Watcher must not inherit our stdout: when the engine's output is being
    # captured, an orphaned sleep holding the pipe would stall the capture.
    ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 &
    local watcher=$!
    local rc=0
    wait "$pid" 2>/dev/null || rc=$?
    kill -TERM "$watcher" 2>/dev/null || true
    return "$rc"
  fi
}

rc=0
review=$(run_with_timeout "$timeout_secs" "${SUPERCRITIC_CMD[@]}" "$prompt") || rc=$?
if [ "$rc" -ne 0 ]; then
  # 124 = GNU timeout; 137 = 128+SIGKILL (timeout -k); 143 = 128+SIGTERM from the bash fallback.
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] || [ "$rc" -eq 143 ]; then
    die "supercritic CLI timed out after ${timeout_secs}s (check SUPERCRITIC_CMD invocation)"
  fi
  die "supercritic CLI failed (exit $rc)"
fi
# An empty review exiting 0 would read as "nothing to address" — fail loud instead.
[ -n "$review" ] || die "supercritic CLI exited 0 but produced no output (check SUPERCRITIC_CMD invocation)"
printf '%s\n' "$review"
