---
name: evidence-driven-drafting
description: "Execute research and writing plans with specialist agents for each task. Researcher gathers evidence, Fact-Checker verifies claims, Ethical Reviewer assesses impact."
---

# Evidence-Driven Drafting

## Overview

This skill coordinates specialist agents to execute research and writing plans. Each task is handled by a fresh agent with the right expertise (Archivist for records, Analyst for data, etc.), then fact-checked and ethically reviewed before proceeding.

**Announce at start:** "I'm using evidence-driven-drafting to research and write this story task-by-task."

## Workflow

For each task in the plan:

1. **Dispatch Specialist Researcher**
   - Read task description from plan
   - Determine which specialist is needed (Archivist/Analyst/Narrator/etc.)
   - Spawn fresh Task agent with specialist prompt
   - Agent researches and documents findings with sources

2. **Fact-Check Review**
   - Spawn fresh Fact-Checker agent
   - Verify: every claim sourced, quotes exact, causal claims marked, dates/names accurate
   - Agent reports: ✓ verified / ⚠ needs revision / ✗ unsupported claim

3. **Ethical Review** (for drafts involving people/communities)
   - Spawn fresh Ethical Reviewer agent (Ethicist + Community Listener perspective)
   - Check: potential harm, missing voices, power dynamics, positionality
   - Agent reports: ✓ responsible / ⚠ revise / ✗ consult community first

4. **Save with Methodology**
   - Save source notes, drafts, and research logs
   - Commit (or timestamp backup) with methodology note

## Task Dispatch Pattern

```markdown
For Task [N]: [Title]

**Specialist needed:** [Archivist/Analyst/Ethicist/Narrator/Skeptic/Community-Listener]

**Prompt:**
[Include complete task description from plan, expected sources, output format]
[Reference: skills/evidence-driven-drafting/researcher-prompt.md]

**After research:**
- Fact-check with Fact-Checker agent
- If draft involves people: Ethical review
- Save with sources
```

## Progress Tracking

Use TodoWrite to track:
- [ ] Task N: Research [topic] - Status: researching / fact-checking / ethical-review / complete
- [ ] Task N+1: Draft [section] - Status: pending

## Key Principles

- **Evidence before claims**: Research first, draft second, verify third
- **Fresh agents per task**: No context contamination
- **Fact-check everything**: Every claim needs a source
- **Ethics at every step**: Check for harm before publishing
- **Methodology transparency**: Document how you found things, not just what you found
