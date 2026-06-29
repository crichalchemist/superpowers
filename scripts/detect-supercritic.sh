#!/usr/bin/env bash
# detect-supercritic.sh — report independent-review-capable AI CLIs
# installed, harness running. Reports only; never decides, never
# executes candidate CLI, never installs anything.
#
# Model family NOT inferred from binary name (CLI like `agy` can be
# backed by Gemini, Claude, or GPT). Establish CLI's model in
# recommendation dialogue, steer toward DIFFERENT family harness.
#
# Usage: scripts/detect-supercritic.sh
# Output: one TAB-separated line per installed CLI ("<name>\t<path>\t<note>"),
#         final "harness\t<claude-code|cursor|copilot|unknown>" line.

set -euo pipefail

CANDIDATES=(agy codex cursor-agent llm ollama gemini)

for cli in "${CANDIDATES[@]}"; do
  path=$(command -v "$cli" 2>/dev/null) || continue
  note=""
  [ "$cli" = "gemini" ] && note="EOLed-upstream(#1846)"
  printf '%s\t%s\t%s\n' "$cli" "$path" "$note"
done

# Harness detection mirrors hooks/session-start (env set by harness).
if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
  harness="cursor"
elif [ -n "${COPILOT_CLI:-}" ]; then
  harness="copilot"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  harness="claude-code"
else
  harness="unknown"
fi
printf 'harness\t%s\n' "$harness"
