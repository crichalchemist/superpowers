---
name: story-plan
description: "Create comprehensive research and drafting plans for investigative stories. Breaks work into bite-sized, verifiable tasks with fact-checking at each step."
---

# Story Planning

## Overview

Write comprehensive research and drafting plans assuming the writer/researcher has limited investigative journalism training. Document everything they need: which sources to consult, what questions to ask, how to verify claims, where to save notes. Break the work into bite-sized tasks. Fact-check everything. Cite sources. Frequent saves.

Assume they are a thoughtful writer but may not know rigorous investigative methods or ethical considerations.

**Announce at start:** "I'm using the story-plan skill to create the research and drafting plan."

**Save plans to:** `writing/plans/YYYY-MM-DD-<story-name>.md`

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Research property ownership records" - step
- "Document findings in source notes" - step
- "Write draft paragraph with inline citations" - step
- "Fact-check claims against sources" - step
- "Save with source notes" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Story Title] Research & Drafting Plan

> **For Claude:** REQUIRED SUB-SKILL: Use narrative:evidence-driven-drafting to implement this plan task-by-task.

**Investigation Goal:** [One sentence: what you're uncovering]

**Narrative Approach:** [Personal essay / Investigative feature / Hybrid investigation]

**Key Actors:** [Who benefits, who's harmed, who has power]

**Ethical Considerations:** [Potential harm, positionality, missing voices]

**Timeline:** [Critical moments to trace]

---
```

## Task Structure

```markdown
### Task N: [Research/Drafting Component]

**Resources:**
- Search: [Specific databases, archives, or web searches]
- Documents: `writing/sources/exact-document-name.pdf`
- Notes: `writing/field-notes/YYYY-MM-DD-location-or-topic.md`
- Draft: `writing/drafts/section-name.md`

**Step 1: Research [specific question]**

Query: [Exact search terms or archive to consult]
Tool: WebSearch / Read / WebFetch
Expected: [What you're looking for: dates, names, financial figures]

**Step 2: Document findings with sources**

Create: `writing/source-notes/topic-name.md`

\`\`\`markdown
## [Topic/Question]

**Source:** [Full citation with URL/archive location]
**Date accessed:** YYYY-MM-DD
**Key findings:**
- [Specific claim with page/paragraph reference]
- [Relevant quote with attribution]

**Confidence:** High / Medium / Low (and why)
**Follow-up questions:** [What this raises]
\`\`\`

**Step 3: Draft paragraph with inline citations**

In: `writing/drafts/section-name.md`

\`\`\`markdown
[Draft paragraph]

The rent increases weren't random. Property records show that between 2020 and 2022, three buildings on Telegraph Avenue were purchased by a Delaware-registered LLC, Oakmont Holdings^[Source: Alameda County Assessor records, accessed 2024-01-15, parcel IDs 123-456-789, 123-456-790, 123-456-791]. The LLC traces back to a San Francisco-based real estate investment trust^[Source: Delaware corporate registry, entity #7654321].

[Continue draft with sources]
\`\`\`

**Step 4: Fact-check draft claims**

Review checklist:
- [ ] Every factual claim has a source
- [ ] Quotes are exact (not paraphrased without attribution)
- [ ] Causal claims are marked as inference or supported
- [ ] Names, dates, figures are verified against source documents
- [ ] Missing context or counterevidence is noted

**Step 5: Save with methodology note**

Save files and add git commit (or timestamped backup):

\`\`\`bash
git add writing/source-notes/topic-name.md writing/drafts/section-name.md
git commit -m "research: document [topic] with primary sources"
\`\`\`
```

## Remember
- Exact source citations always (URL, date accessed, page/paragraph)
- Complete research questions in plan (not "find more info")
- Fact-check before claims
- Reference specialist agents: @archivist @analyst @ethicist @narrator @skeptic @community-listener
- Cite sources, verify claims, frequent saves

## Execution Handoff

After saving the plan, offer execution choice:

**"Research plan complete and saved to `writing/plans/<filename>.md`. Two execution options:**

**1. Evidence-Driven Drafting (this session)** - I dispatch specialist agents per task (Archivist for records, Analyst for data, Ethicist for impact review), fact-check between tasks, iterative research and writing

**2. Parallel Session (separate)** - Open new session with evidence-driven-drafting skill, batch research with review checkpoints

**Which approach?"**
