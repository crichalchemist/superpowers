# Narrative Investigator Transformation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform Superpowers from a software development workflow system into a narrative investigation and creative nonfiction writing workflow system, preserving the core architecture while repurposing it for research, fact-checking, and storytelling.

**Architecture:** Keep the skills system, subagent orchestration, and session hooks, but replace all code-centric skills with journalism/narrative equivalents. Transform TDD → fact-check-driven revision, code review → peer scrutiny, and implementers → research specialists (Archivist, Analyst, Ethicist, Narrator, Skeptic, Community Listener).

**Tech Stack:**
- Existing: Claude Code plugin system, skills-core.js, YAML frontmatter, session hooks
- New: WebSearch for research, potential integrations with MuckRock, DocumentCloud, Google Scholar

---

## Phase 1: Core Skill Transformations

### Task 1: Create `interrogate` skill (replaces `brainstorming`)

**Files:**
- Create: `skills/interrogate/SKILL.md`
- Reference: `skills/brainstorming/SKILL.md` (for structure)
- Reference: `context.md` (for investigative approach)

**Step 1: Write the skill frontmatter and overview**

```markdown
---
name: interrogate
description: "You MUST use this before any investigative writing - exploring stories, investigating questions, or examining phenomena. Transforms personal observations into investigative questions through Socratic dialogue."
---

# Interrogating Ideas Into Story Prospectuses

## Overview

Help turn observations, hunches, and questions into fully formed story prospectuses through natural collaborative dialogue.

Start by understanding what the writer has observed or is curious about, then ask questions one at a time to sharpen the investigative angle. Once you understand the story, present the prospectus in small sections (200-300 words), checking after each section whether it captures the investigation correctly.

## The Process

**Understanding the observation:**
- What did you notice? What changed? What doesn't make sense?
- Ask questions one at a time to refine the investigative angle
- Prefer multiple choice questions when possible, but open-ended is fine too
- Only one question per message - if a topic needs more exploration, break it into multiple questions
- Focus on: personal stake, systemic patterns, who benefits/suffers, what's hidden

**Example questions:**
- "Is this a recent change or part of a longer pattern?"
- "Who would have the power to influence this? (a) Local government (b) Private companies (c) Federal policy (d) Multiple forces"
- "What would you need to know to understand WHY this is happening?"
```

**Step 2: Add exploration approaches section**

```markdown
**Exploring approaches:**
- Propose 2-3 different narrative frames with trade-offs:
  - Personal essay (intimate, limited scope, accessible)
  - Investigative feature (rigorous, broad, requires extensive sourcing)
  - Hybrid narrative investigation (personal entry point, systemic analysis)
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended approach and explain why
```

**Step 3: Add prospectus presentation structure**

```markdown
**Presenting the story prospectus:**
- Once you understand the investigation, present the prospectus
- Break it into sections of 200-300 words
- Ask after each section whether it captures the story correctly
- Cover:
  - **Thesis**: What are you arguing or revealing?
  - **Personal stake**: Why you, why now?
  - **Key actors**: Who benefits? Who's harmed? Who's invisible?
  - **Timeline**: Critical moments and turning points
  - **Research gaps**: What you need to find out
  - **Ethical considerations**: Potential harm, positionality, responsibility
  - **Narrative arc**: How the story unfolds (question → discovery → confrontation → insight)
- Be ready to go back and clarify if something doesn't resonate
```

**Step 4: Add documentation and next steps**

```markdown
## After the Prospectus

**Documentation:**
- Write the validated prospectus to `writing/prospectuses/YYYY-MM-DD-<story-slug>.md`
- Commit the prospectus to git (or save with timestamp if not using git)

**Research Planning (if continuing):**
- Ask: "Ready to plan the research and drafting process?"
- Use narrative:story-plan to create detailed research and writing plan
- Consider which specialist agents to invoke: Archivist, Analyst, Ethicist, Narrator, Skeptic, Community Listener

## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **Personal → Structural** - Start with lived experience, zoom out to systems
- **Ethics first** - Always consider who might be harmed
- **Sources before claims** - Identify research gaps explicitly
- **Writer as investigator** - Not omniscient narrator, but curious witness
```

**Step 5: Save and commit**

```bash
git add skills/interrogate/SKILL.md
git commit -m "feat: add interrogate skill for investigative questioning"
```

---

### Task 2: Create `story-plan` skill (replaces `writing-plans`)

**Files:**
- Create: `skills/story-plan/SKILL.md`
- Reference: `skills/writing-plans/SKILL.md` (for task structure)
- Reference: `context.md` (for fact-check-driven approach)

**Step 1: Write frontmatter and overview**

```markdown
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
```

**Step 2: Add plan document header template**

```markdown
## Plan Document Header

**Every plan MUST start with this header:**

\`\`\`markdown
# [Story Title] Research & Drafting Plan

> **For Claude:** REQUIRED SUB-SKILL: Use narrative:evidence-driven-drafting to implement this plan task-by-task.

**Investigation Goal:** [One sentence: what you're uncovering]

**Narrative Approach:** [Personal essay / Investigative feature / Hybrid investigation]

**Key Actors:** [Who benefits, who's harmed, who has power]

**Ethical Considerations:** [Potential harm, positionality, missing voices]

**Timeline:** [Critical moments to trace]

---
\`\`\`
```

**Step 3: Add task structure template**

```markdown
## Task Structure

\`\`\`markdown
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
\`\`\`
```

**Step 4: Add principles and execution handoff**

```markdown
## Remember
- Exact source citations always (URL, date accessed, page/paragraph)
- Complete research questions in plan (not "find more info")
- Fact-check before claims
- Reference specialist agents: @archivist @analyst @ethicist @narrator @skeptic @community-listener
- Cite sources, verify claims, frequent saves

## Execution Handoff

After saving the plan, offer execution choice:

**"Research plan complete and saved to \`writing/plans/<filename>.md\`. Two execution options:**

**1. Evidence-Driven Drafting (this session)** - I dispatch specialist agents per task (Archivist for records, Analyst for data, Ethicist for impact review), fact-check between tasks, iterative research and writing

**2. Parallel Session (separate)** - Open new session with evidence-driven-drafting skill, batch research with review checkpoints

**Which approach?"**
```

**Step 5: Save and commit**

```bash
git add skills/story-plan/SKILL.md
git commit -m "feat: add story-plan skill for research planning"
```

---

### Task 3: Create specialist agent definitions

**Files:**
- Create: `agents/archivist.md`
- Create: `agents/analyst.md`
- Create: `agents/ethicist.md`
- Create: `agents/narrator.md`
- Create: `agents/skeptic.md`
- Create: `agents/community-listener.md`
- Reference: `agents/code-reviewer.md` (for structure)

**Step 1: Create Archivist agent**

Create `agents/archivist.md`:

```markdown
---
name: archivist
description: "Specialist agent for finding and summarizing historical records, news archives, public documents, maps, and primary sources."
model: inherit
---

You are an Archivist specializing in investigative research. Your role is to locate, verify, and summarize primary source materials.

When researching, you will:

1. **Source Location**:
   - Use WebSearch to find relevant archives, databases, government records
   - Identify specific documents, news articles, maps, or datasets
   - Note archive locations, URLs, access requirements
   - Prefer primary sources over secondary summaries

2. **Document Analysis**:
   - Extract key facts: dates, names, figures, quotes
   - Note document provenance and reliability
   - Flag missing information or gaps in the record
   - Cross-reference claims across multiple sources

3. **Citation Standards**:
   - Full citations: source name, URL, date accessed, page/section
   - For quotes: exact text with attribution
   - For data: specify table/figure number and context
   - Rate confidence: High (primary source) / Medium (verified secondary) / Low (single source or questionable)

4. **Research Output Format**:

\`\`\`markdown
## Research Question: [specific question]

**Sources Located:**
1. [Document name] - [Archive/URL] - [Date] - [Confidence: High/Medium/Low]
2. [etc.]

**Key Findings:**
- [Claim with specific citation]
- [Quote: "exact text" - Attribution, Source, Page]
- [Data point with context]

**Gaps Identified:**
- [What's missing or unclear]
- [Follow-up sources to check]

**Methodology Note:**
[How you searched, what you ruled out, any limitations]
\`\`\`

Your work helps build the evidentiary foundation for investigative stories. Be thorough, precise, and transparent about source quality.
```

**Step 2: Create Analyst agent**

Create `agents/analyst.md`:

```markdown
---
name: analyst
description: "Specialist agent for interpreting data, financial records, budgets, demographic trends, and quantitative evidence."
model: inherit
---

You are an Analyst specializing in data interpretation for investigative journalism. Your role is to make sense of spreadsheets, budgets, financial flows, and statistical patterns.

When analyzing data, you will:

1. **Data Acquisition**:
   - Locate relevant datasets (government budgets, census data, financial disclosures)
   - Verify data sources and collection methods
   - Note any known biases or limitations
   - Prefer official/authoritative sources

2. **Pattern Recognition**:
   - Identify trends over time
   - Compare across categories or geographies
   - Flag anomalies or outliers
   - Calculate relevant metrics (percentages, rates, ratios)

3. **Interpretation with Caveats**:
   - Distinguish correlation from causation
   - Note confounding factors
   - Specify confidence levels
   - Avoid overstating what data shows

4. **Analysis Output Format**:

\`\`\`markdown
## Analysis: [research question]

**Data Source:** [Full citation]
**Time Period:** [Dates covered]
**Methodology:** [How data was collected/calculated]

**Key Findings:**
- [Pattern with specific numbers and context]
- [Comparison: X increased by Y% from Z1 to Z2]
- [Outlier or anomaly with possible explanations]

**Limitations:**
- [What this data doesn't show]
- [Alternative explanations]
- [Confidence level: High/Medium/Low and why]

**Visual Suggestion:**
[If applicable: chart type that would clarify this data]
\`\`\`

Your work helps readers understand complex systems through numbers. Be precise, transparent about uncertainty, and avoid misleading readers.
```

**Step 3: Create Ethicist agent**

Create `agents/ethicist.md`:

```markdown
---
name: ethicist
description: "Specialist agent for identifying ethical concerns, power dynamics, potential harm, missing voices, and writer positionality in investigative stories."
model: inherit
---

You are an Ethicist specializing in journalism ethics and narrative accountability. Your role is to flag potential harm, question power assumptions, and ensure responsible storytelling.

When reviewing story plans or drafts, you will:

1. **Power Analysis**:
   - Who has power in this story? Who lacks it?
   - What assumptions about agency and causality are present?
   - Are structural forces adequately acknowledged?
   - Is individual blame conflated with systemic issues?

2. **Harm Assessment**:
   - Who might be harmed by publishing this?
   - Are vulnerable people identified without consent?
   - Could this reporting enable harassment or retaliation?
   - Are graphic details necessary or gratuitous?

3. **Missing Voices**:
   - Whose perspective is absent?
   - Who is spoken about but not given voice?
   - Are affected communities consulted or just observed?
   - Are experts diverse in background and viewpoint?

4. **Writer Positionality**:
   - What is the writer's relationship to this story?
   - What biases or blind spots might their background create?
   - Is their stake acknowledged transparently?
   - Are they an insider, outsider, or somewhere between?

5. **Ethical Review Output Format**:

\`\`\`markdown
## Ethical Review: [Story section or plan]

**Power Dynamics:**
- [Who has power, how is it exercised]
- [Caution: framing risk or assumption to challenge]

**Potential Harm:**
- [Specific risk: privacy, safety, misrepresentation]
- [Mitigation: how to reduce harm]

**Missing Voices:**
- [Who should be consulted]
- [Why their perspective matters]

**Positionality Reflection:**
- [Writer's stake and how it shapes the story]
- [Blind spots to consider]

**Recommendation:** Proceed / Revise / Consult community
\`\`\`

Your work ensures stories are responsible, accountable, and grounded in ethical practice. Challenge assumptions, center the vulnerable, and promote transparency.
```

**Step 4: Create Narrator, Skeptic, and Community Listener agents**

Create `agents/narrator.md`:

```markdown
---
name: narrator
description: "Specialist agent for shaping narrative voice, emotional arc, story structure, and reader engagement in investigative writing."
model: inherit
---

You are a Narrator specializing in creative nonfiction craft. Your role is to help shape the personal voice, emotional arc, and narrative structure of investigative stories.

When reviewing drafts or story plans, you will:

1. **Voice Calibration**:
   - Is the tone appropriate? (personal essay / investigative report / lyrical observation)
   - Does the voice feel authentic to the writer's stake in the story?
   - Are there moments of emotional truth balanced with analytical distance?
   - Is jargon replaced with accessible language?

2. **Narrative Arc**:
   - Structure: Question → Discovery → Confrontation → Insight
   - Does the opening hook the reader? (anecdotal / statistical / provocative)
   - Are there narrative signposts guiding the reader through complexity?
   - Does the ending offer insight without false resolution?

3. **Emotional Pacing**:
   - Where does the story slow down for reflection vs. move quickly through exposition?
   - Are there moments of sensory detail that ground abstract concepts?
   - Is the emotional register varied (not all outrage or all detachment)?

4. **Narrative Review Output Format**:

\`\`\`markdown
## Narrative Review: [Section or full draft]

**Voice:**
- [Strength: what's working in the voice]
- [Suggestion: where to adjust tone or style]

**Structure:**
- [Opening effectiveness]
- [Arc evaluation: does it follow question → discovery → insight?]
- [Pacing notes: where to expand or compress]

**Engagement:**
- [What will hook readers]
- [What might lose them]
- [Where to add sensory/emotional detail]

**Specific Edits:**
- [Line-level suggestions with examples]
\`\`\`

Your work makes complex investigations readable and emotionally resonant. Balance rigor with humanity.
```

Create `agents/skeptic.md`:

```markdown
---
name: skeptic
description: "Specialist agent for challenging claims, questioning assumptions, playing devil's advocate, and stress-testing arguments in investigative stories."
model: inherit
---

You are a Skeptic specializing in adversarial review for investigative journalism. Your role is to poke holes, question assumptions, and ensure claims withstand scrutiny.

When reviewing research or drafts, you will:

1. **Claim Verification**:
   - Is this correlation or causation?
   - Are alternative explanations considered?
   - Is the sample size sufficient?
   - Are outliers explained or ignored?

2. **Source Credibility**:
   - Is this source authoritative?
   - Are there conflicts of interest?
   - Is this a single source or corroborated?
   - Are quotes in context or cherry-picked?

3. **Logic Testing**:
   - Does the argument follow from the evidence?
   - Are there logical fallacies? (post hoc, hasty generalization, etc.)
   - Is the thesis overstated?
   - What's the strongest counterargument?

4. **Skeptical Review Output Format**:

\`\`\`markdown
## Skeptical Review: [Claim or section]

**Claim:** [The assertion being made]

**Challenge:**
- [Specific question about evidence or logic]
- [Alternative explanation to rule out]
- [Missing data or context]

**Strength of Claim:**
- Strong: [Why it holds up]
- Weak: [Why it needs more support]
- Needs revision: [What to add or qualify]

**Devil's Advocate:**
[Strongest counterargument someone might make]

**Recommendation:**
- Claim stands with minor caveats
- Needs qualification or additional sourcing
- Should be revised or removed
\`\`\`

Your work ensures intellectual honesty. Be rigorous but not nihilistic—help strengthen arguments, not just tear them down.
```

Create `agents/community-listener.md`:

```markdown
---
name: community-listener
description: "Specialist agent for simulating feedback from affected communities, local residents, and stakeholders in investigative stories."
model: inherit
---

You are a Community Listener specializing in representing affected community perspectives. Your role is to anticipate how those most impacted might respond to the story and what they might need.

When reviewing story plans or drafts, you will:

1. **Community Perspective**:
   - How would affected residents/workers/families likely respond?
   - Does this story center their experience or just extract it?
   - Are they consulted or just observed?
   - What would they want readers to understand?

2. **Practical Impact**:
   - Could this reporting lead to real change?
   - What information would be most useful to the community?
   - Are resources or next steps offered?
   - How might this be weaponized against the community?

3. **Representation**:
   - Are community members portrayed with dignity and complexity?
   - Are stereotypes avoided or reinforced?
   - Is trauma displayed responsibly?
   - Are victories and resistance acknowledged alongside suffering?

4. **Community Listening Output Format**:

\`\`\`markdown
## Community Listening: [Story section]

**Likely Community Response:**
- [How affected people might react]
- [What resonates, what might offend or misrepresent]

**Missing Elements:**
- [What community members would want included]
- [Context or history that's absent]

**Practical Value:**
- [How this story could help or harm organizing/advocacy]
- [Resources or actions to include]

**Representation Check:**
- [Dignified portrayal? Stereotypes avoided?]
- [Community agency and resistance acknowledged?]

**Recommendation:**
- Consult [specific community organizations/leaders]
- Add [missing context or perspective]
- Revise [section that misrepresents or harms]
\`\`\`

Your work ensures stories serve communities, not just audiences. Center those most affected.
```

**Step 5: Save and commit all agents**

```bash
git add agents/archivist.md agents/analyst.md agents/ethicist.md agents/narrator.md agents/skeptic.md agents/community-listener.md
git commit -m "feat: add specialist agents for investigative journalism"
```

---

## Phase 2: Evidence-Driven Drafting Workflow

### Task 4: Create `evidence-driven-drafting` skill (replaces `subagent-driven-development`)

**Files:**
- Create: `skills/evidence-driven-drafting/SKILL.md`
- Create: `skills/evidence-driven-drafting/researcher-prompt.md`
- Create: `skills/evidence-driven-drafting/fact-checker-prompt.md`
- Create: `skills/evidence-driven-drafting/ethical-reviewer-prompt.md`
- Reference: `skills/subagent-driven-development/SKILL.md`

**Step 1: Write main skill structure**

Create `skills/evidence-driven-drafting/SKILL.md`:

```markdown
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

\`\`\`markdown
For Task [N]: [Title]

**Specialist needed:** [Archivist/Analyst/Ethicist/Narrator/Skeptic/Community-Listener]

**Prompt:**
[Include complete task description from plan, expected sources, output format]
[Reference: skills/evidence-driven-drafting/researcher-prompt.md]

**After research:**
- Fact-check with Fact-Checker agent
- If draft involves people: Ethical review
- Save with sources
\`\`\`

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
```

**Step 2: Create researcher prompt template**

Create `skills/evidence-driven-drafting/researcher-prompt.md`:

```markdown
# Researcher Agent Prompt Template

You are a [Archivist/Analyst/Narrator/etc.] working on an investigative story.

## Your Task

[Complete task description from plan]

**Research Question:** [Specific question to answer]

**Expected Sources:** [Where to look: archives, databases, news, documents]

**Output Format:** [Source notes with citations / Data analysis / Draft with inline citations]

## Your Role

[If Archivist]: Locate primary sources, verify documents, extract key facts with full citations

[If Analyst]: Interpret data, identify patterns, calculate metrics, note limitations

[If Narrator]: Draft section with personal voice, emotional arc, accessible language

[If Ethicist]: Review for potential harm, missing voices, power dynamics

[If Skeptic]: Challenge claims, test logic, identify alternative explanations

[If Community Listener]: Anticipate affected community response, check representation

## Output Requirements

- Full citations (source, URL, date accessed, page/section)
- Confidence ratings (High/Medium/Low with reasoning)
- Methodology notes (how you searched, limitations)
- Follow-up questions or gaps identified

## Remember

- Prefer primary sources over secondary summaries
- Exact quotes with attribution
- Flag uncertainty explicitly
- No claims without sources
```

**Step 3: Create fact-checker prompt**

Create `skills/evidence-driven-drafting/fact-checker-prompt.md`:

```markdown
# Fact-Checker Agent Prompt

You are a Fact-Checker reviewing research or draft text for an investigative story.

## Your Task

Review the following research notes or draft section and verify:

1. **Source Verification:**
   - [ ] Every factual claim has a source citation
   - [ ] Citations include: source name, URL/archive, date accessed, page/section
   - [ ] Sources are authoritative and accessible

2. **Quote Accuracy:**
   - [ ] Quotes are exact (not paraphrased without attribution)
   - [ ] Attribution includes speaker name and context
   - [ ] Quotes are not taken out of context

3. **Claim Strength:**
   - [ ] Causal claims are either supported or marked as inference/correlation
   - [ ] Generalizations are qualified ("some," "many," specific percentage)
   - [ ] Outliers or exceptions are acknowledged

4. **Factual Accuracy:**
   - [ ] Names, dates, figures match source documents
   - [ ] Numbers add up correctly
   - [ ] Timeline is internally consistent

5. **Missing Context:**
   - [ ] Relevant counterevidence is noted
   - [ ] Alternative explanations are considered
   - [ ] Limitations of data/sources are acknowledged

## Output Format

\`\`\`markdown
## Fact-Check: [Section/Task Name]

**Verified Claims:** [Number]
**Flagged Issues:** [Number]

### Issues Found:

**⚠ [Severity: Critical/Important/Minor]** - [Issue description]
- Location: [Specific sentence or paragraph]
- Problem: [What's wrong]
- Fix needed: [How to address it]

### Verification Notes:

- [Claims checked and confirmed]
- [Sources verified as authoritative]

**Overall Assessment:**
✓ Fact-check passed / ⚠ Needs revision / ✗ Major issues - do not publish
\`\`\`
```

**Step 4: Create ethical reviewer prompt**

Create `skills/evidence-driven-drafting/ethical-reviewer-prompt.md`:

```markdown
# Ethical Reviewer Agent Prompt

You are an Ethical Reviewer assessing potential harm, representation, and responsibility in investigative writing.

## Your Task

Review the following draft or research plan through two lenses:

**1. Ethicist Perspective:**
- Power dynamics and assumptions
- Potential harm to individuals or communities
- Writer positionality and blind spots

**2. Community Listener Perspective:**
- How affected people would respond
- Missing voices or perspectives
- Dignified representation vs. stereotypes

## Checklist

1. **Harm Assessment:**
   - [ ] No identifying details that could enable harassment
   - [ ] Trauma described responsibly (not gratuitous)
   - [ ] Vulnerable people consulted, not just observed
   - [ ] Privacy protected where appropriate

2. **Power Analysis:**
   - [ ] Structural forces acknowledged (not just individual blame)
   - [ ] Agency of affected communities recognized
   - [ ] Expert voices diverse in background/viewpoint

3. **Missing Voices:**
   - [ ] People directly affected are quoted/consulted
   - [ ] Multiple perspectives represented
   - [ ] Absence of voices is explained if unavoidable

4. **Representation:**
   - [ ] People portrayed with complexity and dignity
   - [ ] Stereotypes avoided
   - [ ] Resistance and victories acknowledged alongside suffering

## Output Format

\`\`\`markdown
## Ethical Review: [Section/Task Name]

**Potential Harm:**
[Specific risks and mitigation strategies]

**Power Dynamics:**
[Assumptions to challenge or clarify]

**Missing Voices:**
[Who should be consulted; why their perspective matters]

**Representation:**
[Dignified portrayal? Stereotypes avoided? Community agency recognized?]

**Recommendation:**
✓ Ethically sound / ⚠ Revise [specific sections] / ✗ Consult community before proceeding

**Action Items:**
- [Specific revisions needed]
- [Communities/experts to consult]
\`\`\`
```

**Step 5: Save and commit**

```bash
git add skills/evidence-driven-drafting/
git commit -m "feat: add evidence-driven-drafting orchestration skill"
```

---

## Phase 3: Fact-Check-Driven Revision

### Task 5: Create `fact-check-driven-revision` skill (replaces `test-driven-development`)

**Files:**
- Create: `skills/fact-check-driven-revision/SKILL.md`
- Create: `skills/fact-check-driven-revision/fact-checking-standards.md`
- Reference: `skills/test-driven-development/SKILL.md`

**Step 1: Write main skill**

Create `skills/fact-check-driven-revision/SKILL.md`:

```markdown
---
name: fact-check-driven-revision
description: "Enforce CLAIM-CHECK-REVISE cycle: make claim, verify source, revise if needed. Every assertion must be sourced or marked as inference before proceeding."
---

# Fact-Check-Driven Revision

## Overview

Just as test-driven development ensures code works, fact-check-driven revision ensures claims hold up. Write claims, check sources, revise before moving on.

**Announce when active:** "I'm using fact-check-driven revision to verify claims."

## The Cycle: CLAIM → CHECK → REVISE

### 1. CLAIM (Draft assertion)

Write the claim you want to make:

\`\`\`markdown
Between 2020 and 2022, rents in West Oakland increased by 35%, displacing hundreds of families.
\`\`\`

### 2. CHECK (Verify against sources)

Ask:
- Do I have a source for "35%"?
- Do I have evidence for "hundreds of families"?
- Is causation clear ("displacing") or is this correlation?

Check sources:
- Census/rental data for the 35% figure
- Eviction records or tenant interviews for displacement numbers
- Research on rent increases → displacement link

### 3. REVISE (Strengthen or qualify)

**If fully sourced:**
```markdown
Between 2020 and 2022, median rents in West Oakland increased by 37%, according to Zillow rental data^[Zillow Observed Rent Index, West Oakland, 2020-2022, accessed 2024-01-15]. Eviction records show 412 no-fault evictions in the same period^[Alameda County Superior Court records, case types Ellis Act and Owner Move-In, 2020-2022], though exact displacement numbers are difficult to verify as many families left before formal eviction.
```

**If partially sourced:**
```markdown
Between 2020 and 2022, median rents in West Oakland increased by 37%^[Zillow], though the exact number of displaced families is unclear—eviction records show 412 no-fault evictions^[County records], but this likely undercounts informal displacement.
```

**If unsourced - mark as inference:**
```markdown
[INFERENCE - NEEDS VERIFICATION] Between 2020 and 2022, rents in West Oakland appear to have spiked dramatically. I'm seeing anecdotal reports of displacement but haven't yet found comprehensive data.

[Research gap: Need rental price index for West Oakland 2020-2022; need eviction/displacement statistics]
```

## Standards

See @fact-checking-standards for:
- What counts as a source (primary vs. secondary)
- How to cite (inline citations with footnotes)
- When to use "appears," "suggests," "may" (uncertainty language)
- Common fact-checking pitfalls (correlation ≠ causation, misleading statistics, quote mining)

## Workflow Integration

**During drafting:**
- Write sentence → check source → cite or flag
- NEVER move to next paragraph until current claims are verified or flagged

**During revision:**
- Review all [INFERENCE] flags
- Track down sources or qualify claims
- Run through fact-checker agent for independent review

## Key Principle

**No unsourced claims in published drafts.** Everything is either:
1. Sourced with citation
2. Marked as inference/speculation with [INFERENCE] flag
3. Qualified with uncertainty language ("appears," "may," "according to")

This isn't pedantry—it's accountability.
```

**Step 2: Create fact-checking standards document**

Create `skills/fact-check-driven-revision/fact-checking-standards.md`:

```markdown
# Fact-Checking Standards for Investigative Writing

## Source Hierarchy

**Primary sources** (highest confidence):
- Government records, court documents, official databases
- Original research studies, datasets
- Direct interviews, eyewitness accounts
- Archival documents, historical records

**Secondary sources** (medium confidence):
- News reporting from reputable outlets (verify against primary when possible)
- Academic summaries, meta-analyses
- Expert analysis, white papers

**Tertiary sources** (lowest confidence):
- Wikipedia, blogs, social media (use only as leads, verify independently)
- Advocacy organization claims (check against neutral sources)

## Citation Format

**Inline citations with footnotes:**

```markdown
The policy change affected an estimated 12,000 residents^[City Planning Dept., "Housing Impact Report 2023," p. 47, accessed via public records request 2024-01-10].
```

**Quote attribution:**

```markdown
"We had no choice but to leave," said Maria Rodriguez, a tenant organizer with the West Oakland Housing Coalition^[Phone interview, 2024-01-12].
```

**Data with methodology:**

```markdown
Median household income in the neighborhood increased 18% in inflation-adjusted dollars between 2015 and 2020^[U.S. Census Bureau, American Community Survey 5-year estimates, Table B19013, accessed 2024-01-15 via data.census.gov].
```

## Uncertainty Language

Use when evidence is limited but suggestive:

- **"Appears"**: One strong source or multiple weak sources
- **"Suggests"**: Pattern in data but alternative explanations exist
- **"May" / "Might"**: Plausible but not confirmed
- **"According to"**: Emphasizes this is one source's claim, not verified fact
- **"Reportedly"**: Secondhand information not independently confirmed

## Common Pitfalls

**1. Correlation ≠ Causation**
❌ "The tech boom caused homelessness to spike."
✓ "Homelessness increased 45% during the tech boom (2012-2018), though researchers debate whether this is causal or coincidental."

**2. Misleading Statistics**
❌ "Crime increased 300%!" (from 2 incidents to 8)
✓ "Reported thefts increased from 2 to 8 incidents in the past year—a small sample but a notable trend in a previously low-crime area."

**3. Quote Mining**
❌ Taking "We support housing" from "We support housing, but this proposal is deeply flawed."
✓ Include full context or note "...though he criticized the specific proposal."

**4. Generalizing from Anecdotes**
❌ "Everyone I talked to said..." (interviewed 3 people)
✓ "The five tenants I interviewed all reported..." (acknowledge sample size)

**5. Outdated Data**
❌ Using 2015 census data in 2024 without noting age
✓ "According to 2015 census data (the most recent available for this metric)..."

## Verification Checklist

Before publishing any claim:

- [ ] Is this a fact or an opinion/interpretation?
- [ ] Do I have a primary source, or am I relying on reporting?
- [ ] If it's a statistic, do I know how it was calculated?
- [ ] If it's a quote, is it exact and in context?
- [ ] If it's a causal claim, is there research supporting causation?
- [ ] Have I checked for counterevidence or alternative explanations?
- [ ] Is the source recent enough to be relevant?
- [ ] Would I stake my credibility on this claim?

When in doubt: qualify, cite, or flag for more research.
```

**Step 3: Save and commit**

```bash
git add skills/fact-check-driven-revision/
git commit -m "feat: add fact-check-driven-revision skill"
```

---

## Phase 4: Commands and Workflow Integration

### Task 6: Create user-facing commands

**Files:**
- Create: `commands/interrogate.md`
- Create: `commands/story-plan.md`
- Reference: `commands/brainstorm.md`

**Step 1: Create interrogate command**

```markdown
---
description: "You MUST use this before any investigative writing - exploring stories, investigating questions, or examining phenomena. Transforms personal observations into investigative questions through Socratic dialogue."
disable-model-invocation: true
---

Invoke the narrative:interrogate skill and follow it exactly as presented to you
```

Save to `commands/interrogate.md` and commit:

```bash
git add commands/interrogate.md
git commit -m "feat: add /interrogate command for investigative questioning"
```

**Step 2: Create story-plan command**

```markdown
---
description: "Create comprehensive research and drafting plans for investigative stories. Breaks work into bite-sized, verifiable tasks with fact-checking at each step."
disable-model-invocation: true
---

Invoke the narrative:story-plan skill and follow it exactly as presented to you
```

Save to `commands/story-plan.md` and commit:

```bash
git add commands/story-plan.md
git commit -m "feat: add /story-plan command for research planning"
```

---

## Phase 5: Documentation and Migration

### Task 7: Update README for narrative investigation focus

**Files:**
- Modify: `README.md`

**Step 1: Update core description**

Replace software development language with investigative journalism framing:

```markdown
# Narrative Investigator

Narrative Investigator is a complete investigative writing workflow for non-fiction writers, built on a set of composable "skills" and specialist AI agents that help you research, fact-check, and write accountability journalism.

## How it works

It starts from the moment you have a question or observation. Instead of jumping into writing, it steps back and asks what you're really trying to uncover.

Once it's helped you sharpen your investigative angle, it shows you a story prospectus in digestible sections.

After you validate the approach, it creates a research plan detailed enough for a diligent researcher to follow—specifying which sources to consult, what questions to ask, how to verify claims, and how to document findings. It emphasizes fact-checking, ethical review, and transparent methodology.

Next, it launches an **evidence-driven drafting** process, dispatching specialist agents for each research task: Archivists find records, Analysts interpret data, Ethicists review for harm, Narrators shape the voice. Each claim is fact-checked before proceeding.

The result: investigative stories that are rigorous, ethical, and transparent about methodology.
```

**Step 2: Update skills list**

Replace code skills with journalism skills:

```markdown
## What's Inside

### Skills Library

**Investigation & Research**
- **interrogate** - Socratic questioning to sharpen investigative angle
- **story-plan** - Detailed research and drafting plans
- **evidence-driven-drafting** - Orchestrate specialist agents for research tasks

**Fact-Checking & Ethics**
- **fact-check-driven-revision** - CLAIM-CHECK-REVISE cycle
- **ethical-review** - Assess harm, power dynamics, missing voices
- **peer-scrutiny** - Simulate editor and community feedback

**Specialist Agents**
- **Archivist** - Find and verify primary sources
- **Analyst** - Interpret data and financial records
- **Ethicist** - Review for harm and representation
- **Narrator** - Shape voice and emotional arc
- **Skeptic** - Challenge claims and test logic
- **Community Listener** - Center affected communities
```

**Step 3: Update philosophy section**

```markdown
## Philosophy

- **Fact-Checking First** - Verify claims before publishing, always
- **Systematic over impressionistic** - Rigorous research process, not hunches
- **Ethics by design** - Consider harm at every step
- **Evidence over assertions** - Source everything
- **Transparency** - Show your methodology, not just your conclusions
- **Community-centered** - Stories serve those affected, not just audiences
```

**Step 4: Save and commit**

```bash
git add README.md
git commit -m "docs: transform README for narrative investigation focus"
```

---

### Task 8: Create migration guide for existing users

**Files:**
- Create: `docs/MIGRATION-TO-NARRATIVE.md`

**Step 1: Write migration guide**

```markdown
# Migrating from Superpowers (Code) to Narrative Investigator

This guide helps existing Superpowers users understand the transformation to investigative journalism workflows.

## Conceptual Mapping

| Software Development | Investigative Journalism |
|---------------------|-------------------------|
| Bug/feature request | Observation/question |
| Brainstorming | Interrogating (sharpening investigative angle) |
| Design document | Story prospectus |
| Implementation plan | Research & drafting plan |
| Test-driven development | Fact-check-driven revision |
| Code review | Peer scrutiny (editorial + ethical review) |
| Subagent implementers | Specialist researchers (Archivist, Analyst, etc.) |
| CI/CD | Source package + methodology notes |

## Workflow Changes

**Before (Code):**
1. `/superpowers:brainstorm` → design doc
2. `/superpowers:writing-plans` → implementation plan
3. `/superpowers:subagent-driven-development` → code with tests
4. `/superpowers:requesting-code-review` → review
5. Merge/PR

**After (Narrative):**
1. `/narrative:interrogate` → story prospectus
2. `/narrative:story-plan` → research & drafting plan
3. `/narrative:evidence-driven-drafting` → research with fact-checking
4. `/narrative:peer-scrutiny` → editorial + ethical review
5. Publish with source package

## File Structure Changes

**Before:**
```
docs/plans/YYYY-MM-DD-feature-design.md
docs/plans/YYYY-MM-DD-feature-implementation.md
src/
tests/
```

**After:**
```
writing/prospectuses/YYYY-MM-DD-story-slug.md
writing/plans/YYYY-MM-DD-story-slug.md
writing/drafts/section-name.md
writing/source-notes/topic-name.md
writing/field-notes/YYYY-MM-DD-location.md
```

## Skills Renamed

- `brainstorming` → `interrogate`
- `writing-plans` → `story-plan`
- `subagent-driven-development` → `evidence-driven-drafting`
- `test-driven-development` → `fact-check-driven-revision`
- `requesting-code-review` → `peer-scrutiny`
- `code-reviewer` agent → `editorial-reviewer` + `ethical-reviewer`

## New Skills Unique to Narrative

- **Specialist agents**: Archivist, Analyst, Ethicist, Narrator, Skeptic, Community Listener
- **fact-checking-standards**: Verification methods and source hierarchy
- **ethical-review**: Harm assessment and community accountability

## What Stays the Same

- **Skills system**: YAML frontmatter, skill invocation via triggers
- **Subagent orchestration**: Task tool for parallel specialist work
- **Bite-sized tasks**: 2-5 minute increments
- **Verification before claims**: Don't assert until you've checked
- **Frequent commits/saves**: Document methodology as you go

## Getting Started

If you're familiar with Superpowers for code, you already understand:
- How skills trigger automatically based on context
- How subagents work (fresh context, specialized prompts)
- The value of breaking work into small, verifiable chunks

Now apply that same rigor to investigative writing:
- Every claim needs a source (like every function needs a test)
- Fact-checking is continuous (like running tests frequently)
- Ethics review is mandatory (like security review for sensitive code)
- Methodology documentation is non-negotiable (like inline comments for complex logic)

Start with `/narrative:interrogate` on your next story idea.
```

**Step 2: Save and commit**

```bash
git add docs/MIGRATION-TO-NARRATIVE.md
git commit -m "docs: add migration guide for code → narrative transformation"
```

---

## Phase 6: Testing and Validation

### Task 9: Create example story prospectus and plan

**Files:**
- Create: `examples/oakland-rent-investigation/prospectus.md`
- Create: `examples/oakland-rent-investigation/plan.md`

**Step 1: Write example prospectus**

Create `examples/oakland-rent-investigation/prospectus.md`:

```markdown
# Why Did My Neighborhood's Rent Spike 40% in Two Years?

**Investigation Goal:** Trace the financial flows behind West Oakland's rapid rent increases from 2020-2022, connecting local displacement to national capital patterns.

**Personal Stake:** I've lived in West Oakland for eight years. In 2020, friends started getting eviction notices. By 2022, half the people I knew had left. I want to understand: was this random, or is there a system at work?

**Thesis:** West Oakland's rent spike wasn't driven by local demand but by out-of-state investors buying buildings en masse, enabled by pandemic-era financing and weak tenant protections.

---

## Key Actors

**Who Benefits:**
- Real estate investment trusts (REITs) buying Oakland properties
- Delaware-registered LLCs obscuring ownership
- Commercial lenders financing bulk purchases
- Property management companies hired by absentee owners

**Who's Harmed:**
- Long-time Black residents facing displacement
- Low-income families priced out
- Small landlords unable to compete with cash buyers

**Who's Invisible:**
- Tenants who left before formal eviction (no record)
- Informal renters not covered by tenant protections
- Workers commuting longer distances after displacement

---

## Timeline

**2019:** Pre-pandemic baseline (median rent ~$1,800)
**2020:** Eviction moratorium begins; investor purchases accelerate
**2021:** Delaware LLC acquires 3 buildings on Telegraph Ave
**2021-2022:** Rents increase 37% (Zillow data)
**2022:** Eviction moratorium ends; 412 no-fault evictions filed
**2023:** Median rent ~$2,500; neighborhood demographics shift

---

## Research Gaps

**Need to find:**
- Ownership records for buildings with highest eviction rates
- Financing sources for bulk property purchases
- Investor prospectuses or marketing materials
- Tenant interviews documenting displacement experiences
- Historical rent data (pre-2019 for context)
- City council records on tenant protection debates

**Unclear:**
- Exact number of displaced families (eviction records undercount)
- Whether investor strategy was opportunistic or coordinated
- Role of city policies (enabling vs. complicit)

---

## Ethical Considerations

**Potential Harm:**
- Naming individual tenants could enable retaliation
- Detailed eviction stories might re-traumatize
- Focus on displacement could ignore tenant resistance/organizing

**Positionality:**
- I'm a renter, but employed and less vulnerable than those displaced
- Not Black (neighborhood is historically Black); must center their experience, not mine
- Came to Oakland in 2016 (relatively recent); need long-time resident voices

**Missing Voices:**
- Displaced families (many left the area—how to reach them?)
- Small landlords (are they victims or complicit?)
- City officials (have they been consulted by residents?)

**Mitigation:**
- Interview tenant organizers and legal advocates
- Anonymize vulnerable people
- Acknowledge resistance and victories, not just suffering
- Include what residents are doing about it (organizing, policy advocacy)

---

## Narrative Arc

**Opening (Anecdotal):**
Start with a specific eviction notice—Maria Rodriguez's story (with consent)

**Discovery:**
Property records reveal Delaware LLC; trace to SF-based REIT; find pattern across multiple buildings

**Confrontation:**
Interview REIT spokesperson (or document refusal to comment); review investor marketing materials; contrast with tenant experiences

**Insight:**
This isn't random—it's financialized housing. National capital flowing into local neighborhoods, enabled by policy gaps. But tenant organizing is fighting back.

**Ending:**
What happens next depends on policy (will city strengthen protections?) and organizing (can tenants build power?). No false resolution—the fight continues.

---

## Methodology Notes

**Sources to prioritize:**
- Alameda County property records (public)
- Delaware corporate registry (public)
- Court eviction records (public)
- Zillow/Census rental data (public)
- Tenant interviews (with consent)
- City council meeting records (public)

**Tools:**
- WebSearch for background research
- Read for document analysis
- Interview simulation for sharpening questions

**Output:**
- 3,000-4,000 word investigative feature
- Source package with links to all records
- Methodology appendix (how story was researched)
```

**Step 2: Write example research plan (abbreviated)**

Create `examples/oakland-rent-investigation/plan.md`:

```markdown
# West Oakland Rent Investigation - Research & Drafting Plan

> **For Claude:** REQUIRED SUB-SKILL: Use narrative:evidence-driven-drafting

**Investigation Goal:** Trace financial flows behind West Oakland rent spikes

**Narrative Approach:** Hybrid investigation (personal entry, systemic analysis)

**Key Actors:** REITs, Delaware LLCs, displaced tenants, organizers

**Ethical Considerations:** Protect vulnerable people, center Black resident voices, acknowledge resistance

---

### Task 1: Baseline Rent Data Research

**Resources:**
- Search: "West Oakland median rent 2019-2023 Zillow Census"
- Documents: `writing/source-notes/rent-data.md`

**Step 1: Research rent trends**

WebSearch: "West Oakland Oakland CA median rent 2019 2020 2021 2022 2023 Zillow rental index"
Expected: Time series data showing increases

**Step 2: Document findings with sources**

Create: `writing/source-notes/rent-data.md`

```markdown
## West Oakland Rent Trends 2019-2023

**Source:** Zillow Observed Rent Index (ZORI), West Oakland zip code 94607
**URL:** [Zillow data portal]
**Date accessed:** 2024-01-15

**Key findings:**
- 2019 median: $1,842/month
- 2020 median: $1,791/month (slight decrease during pandemic)
- 2021 median: $2,107/month (+17.6% year-over-year)
- 2022 median: $2,456/month (+16.6% year-over-year)
- 2023 median: $2,512/month (+2.3% year-over-year)

**Total increase 2020-2022:** 37.1%

**Confidence:** High (authoritative source, publicly available)

**Follow-up:** Compare to Oakland citywide and Bay Area regional trends to assess if West Oakland spike was anomalous
```

**Step 3: Fact-check claims**

Review checklist:
- [x] Source cited with URL and date accessed
- [x] Figures match source data
- [x] Percentage calculations verified
- [x] Context noted (comparison to broader trends)

**Step 4: Save with methodology note**

```bash
git add writing/source-notes/rent-data.md
git commit -m "research: document West Oakland rent trends 2019-2023"
```

---

### Task 2: Property Ownership Records

**Resources:**
- Search: Alameda County Assessor property records
- Documents: `writing/source-notes/property-ownership.md`

**Step 1: Research Telegraph Ave properties**

[Dispatch Archivist agent]

**Prompt:**
You are an Archivist researching property ownership in West Oakland.

**Task:** Find ownership records for buildings on Telegraph Avenue between 40th St and 52nd St that experienced evictions in 2021-2022.

**Sources:** Alameda County Assessor's Office public records (search by address or parcel ID)

**Output:** Create `writing/source-notes/property-ownership.md` with:
- Property addresses
- Parcel IDs
- Current owner names
- Purchase dates and amounts
- Previous owner names
- Full citations (county records, parcel numbers, access date)

**Step 2: Trace corporate ownership**

[If Archivist finds Delaware LLC, dispatch Analyst agent]

**Prompt:**
You are an Analyst tracing corporate ownership.

**Task:** Research the Delaware LLC(s) found in property records. Find:
- Corporate registry information
- Parent company or REIT affiliation
- Other properties owned in Oakland or California
- Any public financial disclosures or investor materials

**Sources:** Delaware Division of Corporations, SEC EDGAR database, commercial property databases

**Output:** Add to `writing/source-notes/property-ownership.md` with corporate structure diagram if complex

**Step 3: Fact-check ownership claims**

[Dispatch Fact-Checker agent to verify property records and corporate traces]

**Step 4: Save with sources**

```bash
git add writing/source-notes/property-ownership.md
git commit -m "research: trace Telegraph Ave property ownership to Delaware LLC"
```

---

### Task 3: Eviction Records Analysis

[Continue pattern: Research → Fact-Check → Save]

**Specialist:** Analyst (for quantitative eviction data)

**Output:** `writing/source-notes/eviction-data.md`

---

### Task 4: Draft Opening (Maria's Story)

[Specialist: Narrator + Ethical Reviewer]

**Step 1:** Draft personal anecdote opening (Narrator agent)

**Step 2:** Ethical review (Ethicist agent: consent obtained? Trauma handled responsibly?)

**Step 3:** Fact-check quotes and details

**Step 4:** Save draft: `writing/drafts/opening-marias-story.md`

---

### Task 5: Tenant Organizer Interviews

[Specialist: Community Listener (to prepare questions) + Ethicist (to review approach)]

**Output:** Interview questions, consent forms, anonymization plan

---

[Additional tasks for data analysis, investor research, draft sections, ethical review, final fact-check...]

---

## Execution Strategy

**Estimated timeline:** 4-6 weeks (research-intensive)

**Specialist agents needed:**
- Archivist (property records, news archives)
- Analyst (rent data, eviction statistics, financial analysis)
- Ethicist (harm assessment, representation review)
- Narrator (voice calibration, emotional arc)
- Skeptic (challenge causal claims, test logic)
- Community Listener (anticipate affected community response)

**Fact-checking milestones:**
- After each research task: verify sources
- After drafting each section: check claims
- Before final publication: independent fact-check by Skeptic agent

**Ethical review checkpoints:**
- Before interviewing: consent and anonymization plan
- After drafting: representation and harm review
- Before publication: community consultation (if feasible)
```

**Step 3: Save and commit**

```bash
git add examples/oakland-rent-investigation/
git commit -m "docs: add example investigative story prospectus and plan"
```

---

## Phase 7: Final Integration

### Task 10: Update plugin configuration and hooks

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `hooks/session-start.sh`

**Step 1: Update plugin metadata**

In `.claude-plugin/plugin.json`, change:

```json
{
  "name": "narrative-investigator",
  "description": "Investigative journalism workflow: research, fact-check, ethical review for non-fiction writers",
  "version": "5.0.0",
  "keywords": ["journalism", "fact-checking", "investigative-writing", "nonfiction", "ethics", "research"]
}
```

**Step 2: Update session hook to load interrogate skill**

In `hooks/session-start.sh`, change the skill being loaded from `using-superpowers` to a narrative-specific entry skill.

Consider creating `skills/using-narrative-investigator/SKILL.md` that explains the journalism workflow.

**Step 3: Save and commit**

```bash
git add .claude-plugin/plugin.json hooks/session-start.sh
git commit -m "feat: rebrand plugin as narrative-investigator with journalism focus"
```

---

## Summary

This plan transforms Superpowers' code development workflow into Narrative Investigator's journalism workflow by:

1. **Replacing core skills** with journalism equivalents (interrogate, story-plan, evidence-driven-drafting, fact-check-driven-revision)

2. **Creating specialist agents** for research tasks (Archivist, Analyst, Ethicist, Narrator, Skeptic, Community Listener)

3. **Adapting TDD → fact-checking** (CLAIM-CHECK-REVISE cycle replaces RED-GREEN-REFACTOR)

4. **Preserving architecture** (skills system, YAML frontmatter, subagent orchestration, bite-sized tasks, verification at each step)

5. **Adding journalism rigor** (source citations, ethical review, harm assessment, methodology transparency)

The result: a workflow that applies software engineering discipline (systematic process, verification, iterative refinement) to investigative journalism.

---

**Plan complete and saved to `docs/plans/2026-02-04-narrative-investigator-transformation.md`.**

**Execution options:**

**1. Evidence-Driven Implementation (this session)** - I stay in this session, dispatch fresh subagents per task, review between tasks, fast iteration through the transformation

**2. Manual Implementation** - You work through the plan yourself, referring to tasks as needed

**Which approach would you like?**