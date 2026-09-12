#!/usr/bin/env bash
# reset-toy.sh TOY — return an already-trusted eval toy to a fresh `greeter` branch off `main`,
# with the eval's project settings committed on main. No directory is deleted by hand; git's
# own checkout/clean does the reset so the trusted path itself is untouched.
set -euo pipefail
toy="$1"
cd "$toy"
/usr/bin/git checkout -q -f main
/usr/bin/git branch -D greeter >/dev/null 2>&1 || true
/usr/bin/git clean -fdxq
/usr/bin/git reset -q --hard main
mkdir -p .claude
cat > .claude/settings.json <<'EOF'
{
  "enabledPlugins": { "superpowers@superpowers-marketplace": false },
  "env": { "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1" }
}
EOF
/usr/bin/git add .claude/settings.json
/usr/bin/git commit -q -m "chore: eval project settings (task tools on, marketplace copy off)" || true
/usr/bin/git checkout -q -b greeter
printf 'toy %s ready: %s unchecked boxes, branch %s\n' "$toy" \
  "$(grep -c '^- \[ \]' docs/superpowers/plans/2026-09-11-greeter.md)" \
  "$(/usr/bin/git branch --show-current)"
