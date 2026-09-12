// make-alone.js PLUGIN_DIR — turn a copy of the plugin into the "hook alone" eval artifact:
// remove the explicit check-off instruction from both executing skills so only the
// TaskCompleted hook can tick boxes. Never shipped; eval-only. Each replacement must hit
// exactly once or the script fails loudly.
const fs = require('fs');
const path = require('path');
const dir = process.argv[2];
if (!dir) { console.error('usage: make-alone.js PLUGIN_DIR'); process.exit(2); }

function replaceOnce(file, from, to) {
  const p = path.join(dir, file);
  const text = fs.readFileSync(p, 'utf8');
  const n = text.split(from).length - 1;
  if (n !== 1) { console.error(`${file}: expected 1 hit, found ${n} for:\n${from}`); process.exit(1); }
  fs.writeFileSync(p, text.replace(from, to));
  console.log(`${file}: replaced`);
}

replaceOnce('skills/executing-plans/SKILL.md',
`4. Mark as completed — the task, and the plan file: run
   \`../subagent-driven-development/scripts/plan-checkoff --done N PLAN_FILE\`
   (path relative to this skill's directory) for the task you just finished.
   Exit 4 means a path the task's \`Files:\` block names does not exist yet, or
   the task lists none: the task is not done — fix what is missing, then rerun.
   Marking the task complete runs the same check-off through a hook on Claude
   Code; a refused completion means the task is not done.
`,
`4. Mark as completed — the task. Marking the task complete runs the plan's
   check-off through a hook on Claude Code; a refused completion means the
   task is not done.
`);

replaceOnce('skills/subagent-driven-development/SKILL.md',
`Before deleting the workspace, run \`scripts/plan-checkoff PLAN_FILE\` one last
time, then \`scripts/active-plan clear\` — deletion destroys the ledger, so
this is the last moment the plan's checkboxes can be reconciled from it.
Inspect the resulting \`git diff\` of the
plan before committing:`,
`Before deleting the workspace, run \`scripts/active-plan clear\`.
Inspect the resulting \`git diff\` of the
plan before committing:`);

// sanity: no remaining explicit --done instruction in either skill
for (const f of ['skills/executing-plans/SKILL.md', 'skills/subagent-driven-development/SKILL.md']) {
  const t = fs.readFileSync(path.join(dir, f), 'utf8');
  const hits = (t.match(/plan-checkoff (--done|PLAN_FILE)/g) || []).length;
  console.log(`${f}: remaining explicit plan-checkoff run mentions = ${hits}`);
}
