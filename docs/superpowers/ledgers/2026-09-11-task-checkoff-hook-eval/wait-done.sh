#!/usr/bin/env bash
# wait-done.sh WORKER_NAME [MAX_ROUNDS] — keep waiting for turn ends until the worker's last
# reply line is DONE, or it is gone, or MAX_ROUNDS (default 8 x 590s) elapse.
set -u
name="$1"; max="${2:-8}"
shim="/tmp/csd-workers/bin/$name"
round=0
while [ "$round" -lt "$max" ]; do
  st=$("$shim" status 2>/dev/null || printf 'unknown')
  case "$st" in
    gone|terminated) printf '%s: %s\n' "$name" "$st"; exit 1 ;;
  esac
  last=$("$shim" read-turn 2>/dev/null | grep -v '^[[:space:]]*$' | tail -n 1)
  if [ "$st" = idle ] && [ "$last" = "DONE" ]; then printf '%s: DONE after %s round(s)\n' "$name" "$round"; exit 0; fi
  # idle without DONE = the worker's turn ended while a subagent runs; the next stop
  # arrives when it resumes. Wait for it either way.
  printf '%s: round %s, status %s, last: %s\n' "$name" "$round" "$st" "$last"
  "$shim" wait-for-turn 590 >/dev/null 2>&1
  round=$((round + 1))
done
printf '%s: still working after %s rounds\n' "$name" "$max"
exit 2
