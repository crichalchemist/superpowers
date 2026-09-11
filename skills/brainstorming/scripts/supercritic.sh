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
# Exit codes:
#   0  review printed
#   2  usage error, or the named source file does not exist
#   3  feature off or mis-set — no conf, disabled, unverified, conf tracked by
#      git, git tracked-conf check timed out, empty or unresolvable
#      SUPERCRITIC_CMD. A caller should treat this as "skip", not "broken".
#   4  the supercritic CLI timed out
#   5  the CLI exited non-zero, or exited 0 with no output
#   6  content too large
#
# SAFETY INVARIANT (do not change): reviews go through inline content only — the
# CLI sees only the text we pass, so the review is read-only by construction. No
# repo-access or permission-skipping flags belong in SUPERCRITIC_CMD. `</dev/null`
# is REQUIRED — print-mode CLIs block waiting on stdin otherwise (observed with
# agy: hangs indefinitely). Every CLI call is timeout-guarded so a misconfigured
# CLI fails loud, never hangs.
set -euo pipefail

die() { echo "supercritic: $1" >&2; exit "$2"; }

# Portable timeout: GNU timeout, gtimeout (macOS coreutils), or a bash fallback.
run_with_timeout() {
  local secs=$1; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout -k 5 "$secs" "$@" </dev/null
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout -k 5 "$secs" "$@" </dev/null
  else
    # Fallback: run the CLI in its own process group (set -m) so the watcher can
    # signal the WHOLE group. A CLI that forks a long-lived grandchild would
    # otherwise outlive a kill aimed at its pid alone — and that grandchild
    # inherits our stdout, so it holds the output pipe open and stalls the
    # caller's capture long past the timeout.
    local pid watcher rc=0
    set -m
    "$@" </dev/null &
    pid=$!
    # The watcher is started under `set -m` too, so it leads its own process
    # group and can be group-killed on the way out. Killing the subshell alone
    # orphans the `sleep` it is blocked on, which then holds our stdin open for
    # the rest of the timeout window — on every run, successful ones included.
    # Its output goes to /dev/null: when the engine's output is being captured,
    # an orphan holding that pipe would stall the capture.
    # TERM then KILL after the same 5-second grace the GNU path uses. Each kill
    # signals the group and then the pid alone, so a platform where `set -m`
    # does not give the job its own group degrades to a single-pid kill rather
    # than silently killing nothing at all.
    (
      sleep "$secs"
      kill -TERM -- -"$pid" 2>/dev/null; kill -TERM "$pid" 2>/dev/null
      sleep 5
      kill -KILL -- -"$pid" 2>/dev/null; kill -KILL "$pid" 2>/dev/null
    ) >/dev/null 2>&1 &
    watcher=$!
    set +m
    wait "$pid" 2>/dev/null || rc=$?
    kill -TERM -- -"$watcher" 2>/dev/null || kill -TERM "$watcher" 2>/dev/null || true
    return "$rc"
  fi
}

if [ $# -lt 2 ]; then
  echo "usage: $0 \"<focus>\" <file|->" >&2
  exit 2
fi
focus=$1
src=$2

conf=${SUPERCRITIC_CONF:-.superpowers/supercritic.conf}
[ -f "$conf" ] || die "no config at $conf (run detect-supercritic.sh and configure first)" 3
# Sourcing executes the conf. A conf tracked by git could arrive in a hostile
# clone and run attacker bash the first time a consume hook fires. Legit confs
# are always untracked (setup step 5 gitignores .superpowers/), so refuse.
# A hung git (network filesystem, an index lock held elsewhere) must not hang
# the engine, so the check is itself timeout-guarded. This is an ALLOWLIST, not
# a denylist: only rc 1 (untracked) and 128 (not a git repo) prove the conf is
# safe to source. Every other result — a timeout, a broken git, `timeout` itself
# failing — leaves the question open, and an open question about sourcing
# attacker bash from a hostile clone means refuse.
if command -v git >/dev/null 2>&1; then
  git_rc=0
  run_with_timeout 10 git ls-files --error-unmatch -- "$conf" >/dev/null 2>&1 || git_rc=$?
  case "$git_rc" in
    0) die "$conf is tracked by git — refusing to source it (a committed conf can execute arbitrary code; untrack it and gitignore .superpowers/)" 3 ;;
    1 | 128) ;;
    124 | 137 | 143) die "git tracked-conf check timed out after 10s — refusing to source $conf (cannot prove it is untracked; untrack it and gitignore .superpowers/)" 3 ;;
    *) die "git tracked-conf check failed (exit $git_rc) — refusing to source $conf (cannot prove it is untracked; untrack it and gitignore .superpowers/)" 3 ;;
  esac
fi
# shellcheck source=/dev/null
. "$conf"

[ "${SUPERCRITIC_ENABLED:-0}" = "1" ] || die "supercritic disabled in $conf" 3
if [ "${SUPERCRITIC_SMOKE:-0}" != "1" ]; then
  [ "${SUPERCRITIC_VERIFIED:-0}" = "1" ] || die "supercritic not verified in $conf (smoke test never passed)" 3
fi
# SUPERCRITIC_CMD is set by the sourced conf above; shellcheck cannot follow the source.
# shellcheck disable=SC2154
if ! declare -p SUPERCRITIC_CMD >/dev/null 2>&1 || [ "${#SUPERCRITIC_CMD[@]}" -lt 1 ]; then
  die "SUPERCRITIC_CMD not set as a non-empty bash array in $conf" 3
fi
# A bare name in SUPERCRITIC_CMD resolves through $PATH at run time, so a PATH
# change between setup and now would silently run a different binary than the
# one the user approved. Pin it once, out loud, before the CLI can run.
case "${SUPERCRITIC_CMD[0]}" in
  */*) ;;
  *)
    resolved=$(command -v -- "${SUPERCRITIC_CMD[0]}") \
      || die "SUPERCRITIC_CMD[0] '${SUPERCRITIC_CMD[0]}' not found on PATH (put the absolute path detect-supercritic.sh reported into $conf)" 3
    case "$resolved" in
      */*) ;;
      *) die "SUPERCRITIC_CMD[0] '${SUPERCRITIC_CMD[0]}' resolves to a shell builtin, not a binary (put the absolute path detect-supercritic.sh reported into $conf)" 3 ;;
    esac
    echo "supercritic: resolved ${SUPERCRITIC_CMD[0]} -> $resolved" >&2
    SUPERCRITIC_CMD[0]=$resolved
    ;;
esac

timeout_secs=${SUPERCRITIC_TIMEOUT:-120}
# Validate before use: GNU timeout reads 0 as "no limit", so an unvalidated 0
# switches the SAFETY INVARIANT's timeout guard off entirely and the CLI runs
# unbounded. A non-numeric value produced a different exit code depending on
# which timeout binary the host had. Both are config errors — say so, exit 3.
case "$timeout_secs" in
  '' | *[!0-9]* | 0) die "SUPERCRITIC_TIMEOUT must be a positive integer of seconds (got '$timeout_secs')" 3 ;;
esac

# The prompt travels as ONE exec argument; Linux caps a single argument at
# ~128 KiB (MAX_ARG_STRLEN). Bound well below the cap and fail loud — and check
# the size BEFORE buffering, so an oversize source is refused, never read whole.
MAX_BYTES=100000
if [ "$src" = "-" ]; then
  # Read at most MAX_BYTES+1 so an oversize stream is refused without being
  # drained. The trailing X survives command substitution's newline stripping,
  # so the count below is the true count of what was read — without it, a
  # stream whose byte MAX_BYTES+1 is a newline would be silently truncated to
  # MAX_BYTES and reviewed as if it were the whole document.
  content=$(head -c "$(( MAX_BYTES + 1 ))"; printf 'X')
  content=${content%X}
  content_bytes=$(( $(printf '%s' "$content" | wc -c) ))
  if [ "$content_bytes" -gt "$MAX_BYTES" ]; then
    die "content too large (more than ${MAX_BYTES} bytes) — narrow the diff or split the review" 6
  fi
else
  [ -f "$src" ] || { echo "supercritic: no such file: $src" >&2; exit 2; }
  src_bytes=$(( $(wc -c < "$src") ))
  if [ "$src_bytes" -gt "$MAX_BYTES" ]; then
    die "content too large (${src_bytes} bytes > ${MAX_BYTES}) — narrow the diff or split the review" 6
  fi
  content=$(cat "$src")
fi

prompt=$(cat <<EOF
You are doing a READ-ONLY review. Do not ask follow-up questions; produce the review directly.

Focus: ${focus}

Be critical, specific, and concrete; reference section names or quote the exact text you mean. Cover correctness, risks that would bite during implementation, edge cases, and testability. End with a one-line verdict: ready to proceed, or what must change first.

=== UNDER REVIEW ===
${content}
EOF
)

rc=0
review=$(run_with_timeout "$timeout_secs" "${SUPERCRITIC_CMD[@]}" "$prompt") || rc=$?
if [ "$rc" -ne 0 ]; then
  # 124 = GNU timeout; 137 = 128+SIGKILL (timeout -k); 143 = 128+SIGTERM from the bash fallback.
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] || [ "$rc" -eq 143 ]; then
    die "supercritic CLI timed out after ${timeout_secs}s (check SUPERCRITIC_CMD invocation)" 4
  fi
  die "supercritic CLI failed (exit $rc)" 5
fi
# An empty review exiting 0 would read as "nothing to address" — fail loud instead.
[ -n "$review" ] || die "supercritic CLI exited 0 but produced no output (check SUPERCRITIC_CMD invocation)" 5
printf '%s\n' "$review"
