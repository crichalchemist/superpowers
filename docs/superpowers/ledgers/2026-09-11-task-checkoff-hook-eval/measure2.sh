#!/usr/bin/env bash
# measure2.sh LABEL TOY SESSION_ID PLUGIN_DIR — report the on-disk outcome of one eval run,
# plus the two transcript counts the spec's Eval section adds over measure.sh:
# TaskUpdate completions per plan task, and Bash `--done` calls.
set -u
label="$1"; toy="$2"; sid="$3"; plugin="$4"
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
printf 'plan file committed clean: '
if [ -z "$(/usr/bin/git -C "$toy" status --porcelain -- docs/superpowers/plans/2026-09-11-greeter.md)" ]; then printf 'yes\n'; else printf 'NO (modified in tree)\n'; fi
printf 'marker left behind: '
if [ -e "$toy/.superpowers/sdd/active-plan" ]; then printf 'YES %s\n' "$(cat "$toy/.superpowers/sdd/active-plan")"; else printf 'no\n'; fi
printf 'tests: '
( cd "$toy" && bash tests/test-greet.sh 2>&1 | tail -1; bash tests/test-shout.sh 2>&1 | tail -1 ) | tr '\n' ' '
printf '\n'
printf -- '--verify on the resulting plan:\n'
"$plugin/skills/subagent-driven-development/scripts/plan-checkoff" --verify "$plan" 2>&1 | sed 's/^/  /'
printf '  verify rc=%s\n' "${PIPESTATUS[0]}"
if [ -f "$jsonl" ]; then
  printf 'skill base dirs seen in session:\n'
  grep -o 'Base directory for this skill: [^"\\]*' "$jsonl" | sort -u | sed 's/^/  /'
  printf 'TaskCreate calls: %s\n' "$(grep -o '"name":"TaskCreate"' "$jsonl" | wc -l | tr -d ' ')"
  printf 'TaskCreate subjects:\n'
  grep -o '"name":"TaskCreate","input":{"subject":"[^"]*"' "$jsonl" | sed 's/.*"subject":"//; s/"$//; s/^/  /'
  printf 'TaskUpdate completions: %s\n' "$(grep -o '"name":"TaskUpdate","input":{[^}]*}' "$jsonl" | grep -c '"status":"completed"')"
  printf 'Bash --done calls: %s\n' "$(grep -o '"command":"[^"]*plan-checkoff --done[^"]*"' "$jsonl" | wc -l | tr -d ' ')"
  printf 'Bash --verify calls: %s\n' "$(grep -o '"command":"[^"]*plan-checkoff --verify[^"]*"' "$jsonl" | wc -l | tr -d ' ')"
  printf 'active-plan set/clear calls: %s / %s\n' "$(grep -o '"command":"[^"]*active-plan set[^"]*"' "$jsonl" | wc -l | tr -d ' ')" "$(grep -o '"command":"[^"]*active-plan clear[^"]*"' "$jsonl" | wc -l | tr -d ' ')"
  printf 'hook refusals fed back (plan-checkoff: Task N: ... not flipped): %s\n' "$(grep -o 'plan-checkoff: Task [0-9]*: [^"\\]*not flipped' "$jsonl" | wc -l | tr -d ' ')"
  printf 'plan-checkoff ledger-mode calls (plan as first arg, any quoting): %s\n' "$(grep -o 'plan-checkoff[^ ]\{0,4\} [^ ]\{0,12\}docs/superpowers/plans/2026-09-11-greeter.md' "$jsonl" | grep -vc -- '--')"
  printf 'active-plan set/clear calls (any quoting): %s / %s\n' "$(grep -o 'active-plan[^ ]\{0,4\} set ' "$jsonl" | wc -l | tr -d ' ')" "$(grep -o 'active-plan[^ ]\{0,4\} clear' "$jsonl" | wc -l | tr -d ' ')"
  printf 'session turns (user lines): %s\n' "$(grep -c '"type":"user"' "$jsonl")"
else
  printf 'session jsonl not found at %s\n' "$jsonl"
fi
printf '\n'
# timeline: order of check-off-relevant events in the transcript (line numbers are jsonl lines)
if [ -f "$jsonl" ]; then
  printf 'timeline (jsonl line: event):\n'
  grep -n -o '"name":"TaskUpdate","input":{[^}]*"status":"completed"[^}]*}\|"command":"[^}]\{0,250\}plan-checkoff[^ ]\{0,4\} --done [0-9]*\|"command":"[^}]\{0,250\}plan-checkoff[^ ]\{0,4\} docs/superpowers/plans/2026-09-11-greeter.md\|"command":"[^}]\{0,250\}active-plan[^ ]\{0,4\} \(set\|clear\)\|plan-checkoff: Task [0-9]*: \(missing\|unverified\)[^"\\]*not flipped\|checked off [0-9]* task(s), [0-9]* box(es) in docs' "$jsonl" \
    | sed -E 's/^([0-9]+):"name":"TaskUpdate","input":\{"taskId":"([^"]*)".*/\1: TaskUpdate completed taskId \2/; s/^([0-9]+):"command":".*plan-checkoff[^ ]{0,4} (--done [0-9]+)/\1: Bash plan-checkoff \2/; s/^([0-9]+):"command":".*(plan-checkoff)[^ ]{0,4} docs.*/\1: Bash plan-checkoff (ledger mode)/; s/^([0-9]+):"command":".*active-plan[^ ]{0,4} (set|clear)/\1: Bash active-plan \2/; s/^([0-9]+):(plan-checkoff: Task [0-9]+: .*not flipped)/\1: HOOK REFUSED \2/; s/^([0-9]+):(checked off .*)/\1: ledger-mode result: \2/' \
    | uniq | sed 's/^/  /'
fi
