#!/usr/bin/env bash
# measure.sh LABEL TOY SESSION_ID — report the on-disk outcome of one eval run.
set -u
label="$1"; toy="$2"; sid="$3"
after=/private/tmp/claude-501/-Volumes-Containers-superpowers/02d4b691-b96a-44f5-b7a2-a6ee1a792d4e/scratchpad/eval/plugin-after
plan="$toy/docs/superpowers/plans/2026-09-11-greeter.md"
enc=$(printf '%s' "$toy" | sed 's#[/._]#-#g')
jsonl="$HOME/.claude/projects/$enc/$sid.jsonl"

printf '## %s\n' "$label"
printf 'toy: %s\n' "$toy"
printf 'unchecked boxes: %s\n' "$(grep -c '^- \[ \]' "$plan")"
printf 'checked boxes: %s\n' "$(grep -c '^- \[x\]' "$plan")"
for f in src/greet.sh tests/test-greet.sh src/shout.sh tests/test-shout.sh; do
  if [ -e "$toy/$f" ]; then printf 'exists: %s\n' "$f"; else printf 'MISSING: %s\n' "$f"; fi
done
printf 'commits on greeter: %s\n' "$(/usr/bin/git -C "$toy" rev-list --count main..greeter 2>/dev/null)"
printf 'tests: '
( cd "$toy" && bash tests/test-greet.sh 2>&1 | tail -1; bash tests/test-shout.sh 2>&1 | tail -1 ) | tr '\n' ' '
printf '\n'
printf -- '--verify (after tool) on the resulting plan:\n'
"$after/skills/subagent-driven-development/scripts/plan-checkoff" --verify "$plan" 2>&1 | sed 's/^/  /'
printf '  verify rc=%s\n' "${PIPESTATUS[0]}"
if [ -f "$jsonl" ]; then
  printf 'skill base dirs seen in session:\n'
  grep -o 'Base directory for this skill: [^"\\]*' "$jsonl" | sort -u | sed 's/^/  /'
  printf 'plan-checkoff invocations in session: %s\n' "$(grep -c 'plan-checkoff' "$jsonl")"
  printf 'session turns (user_prompt lines): %s\n' "$(grep -c '"type":"user"' "$jsonl")"
else
  printf 'session jsonl not found at %s\n' "$jsonl"
fi
printf '\n'
