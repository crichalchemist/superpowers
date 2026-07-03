---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Supercritic (if configured)

**Path resolution:**

```bash
SKILL_BASE="<the path the harness announced for this skill>"
ENGINE="$SKILL_BASE/../brainstorming/scripts/supercritic.sh"
```

Fallback if the announcement is not in context:

```bash
ENGINE=$(find ~/.claude/plugins -path '*brainstorming/scripts/supercritic.sh' 2>/dev/null | head -1)
# Other harnesses may use a different plugins root; adjust accordingly.
```

Your working directory stays at the user's project root — this ensures `.superpowers/supercritic.conf` resolves correctly.

After assembling the git SHAs (step 1), check `.superpowers/supercritic.conf` and take one of three branches:

**Enabled and verified** (`SUPERCRITIC_ENABLED=1` and `SUPERCRITIC_VERIFIED=1`): Get an independent different-model pass on the diff before dispatching the reviewer subagent:

```bash
git diff "$BASE_SHA..$HEAD_SHA" | "$ENGINE" "Code review this diff" -
```

If the engine refuses the diff as too large (>100 KB), narrow it with pathspecs
(e.g., `git diff "$BASE_SHA..$HEAD_SHA" -- src/`) and run one pass per area.

Incorporate its findings alongside the subagent reviewer's report.

**Disabled** (`SUPERCRITIC_ENABLED=0`): Skip silently. Proceed to step 2.

**No conf, or conf present but `SUPERCRITIC_VERIFIED` is not `1`** (arrived here without going through brainstorming, or setup was interrupted before the smoke test): Make the one-time offer and run setup as described in the **brainstorming skill's "Supercritic" section**. Once verified, consume as in the first branch above.

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/superpowers/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Integration with Workflows

**Subagent-Driven Development:**
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**
- Review after each task or at natural checkpoints
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before merge
- Review when stuck

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: [code-reviewer.md](code-reviewer.md)
