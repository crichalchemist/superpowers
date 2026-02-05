---
name: evidence-driven-drafting
description: "Execute research and writing plans with specialist agents for each task. Researcher gathers evidence, Fact-Checker verifies claims, Ethical Reviewer assesses impact."
---

# Evidence-Driven Drafting

## Overview

This skill coordinates specialist agents to execute research and writing plans. Each task is handled by a fresh agent with the right expertise (Archivist for records, Analyst for data, etc.), then fact-checked and ethically reviewed before proceeding.

**Voice Context:** If `skills/writing-personality/` exists, the Narrator agent references these files to match your authentic voice during drafting.

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

**Dispatch subagent with appropriate prompt:**
- Archivist: ./archivist-prompt.md (primary sources, archives, Graph of Thoughts)
- Analyst: ./analyst-prompt.md (data analysis, patterns, financial flows)
- Ethicist: ./ethicist-prompt.md (harm assessment, positionality)
- Narrator: ./narrator-prompt.md (storytelling, voice, narrative structure)
- Skeptic: ./skeptic-prompt.md (claims verification, counterarguments)
- Community Listener: ./community-listener-prompt.md (missing voices, power dynamics)

**Include in prompt:**
- Complete task description from plan
- Expected sources and output format
- Research question or drafting goal

**After research:**
- Fact-check with ./fact-checker-prompt.md
- If draft involves people: Ethical review with ./ethical-reviewer-prompt.md
- Save with sources
```

## Prompt Files

Located in this skill directory:
- `./archivist-prompt.md` - Historical records, archives, primary sources specialist
- `./analyst-prompt.md` - Data analysis, financial flows, pattern recognition specialist
- `./ethicist-prompt.md` - Harm assessment, positionality, ethical considerations specialist
- `./narrator-prompt.md` - Storytelling, narrative structure, voice specialist
- `./skeptic-prompt.md` - Claims verification, logical fallacies, counterarguments specialist
- `./community-listener-prompt.md` - Missing voices, power dynamics, community impact specialist
- `./fact-checker-prompt.md` - Source verification, citation accuracy, claim validation
- `./ethical-reviewer-prompt.md` - Post-draft ethical review (harm, representation)
- `./researcher-prompt.md` - Generic template (deprecated - use specific prompts above)

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
