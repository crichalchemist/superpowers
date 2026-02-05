---
name: brainstorming
description: "You MUST use this before any creative work - software features, investigative stories, code components, or written narratives. Explores intent through dialogue, then hands off to appropriate workflow."
---

# Brainstorming Ideas Into Plans

## Overview

Help turn ideas into fully formed designs (code) or prospectuses (writing) through natural collaborative dialogue.

**First question (always):** "Are we building **code** or exploring a **story/investigation**?"

Based on direction, adapt the process to either:
- **Code**: Technical design → implementation plan
- **Story**: Narrative prospectus → research/drafting plan

Present refined concepts in small sections (200-300 words), checking after each section whether it captures the vision correctly.

## The Process

### Path Selection

**First, determine direction:**
- "Are we building **code** or exploring a **story/investigation**?"

Then adapt all subsequent questions based on the answer.

### Understanding the Idea

**For CODE:**
- Check current project state (files, docs, recent commits)
- Ask questions one at a time: purpose, constraints, success criteria
- Focus on: architecture, data flow, edge cases, testing

**For STORY/INVESTIGATION:**
- Ask what they've observed or are curious about
- Ask questions one at a time: personal stake, systemic patterns, who benefits/suffers, what's hidden
- Focus on: thesis, key actors, timeline, research gaps, ethical considerations

**Both paths:**
- One question per message
- Prefer multiple choice when possible, open-ended is fine too
- If a topic needs more exploration, break into multiple questions

### Exploring Approaches

**For CODE:**
- Propose 2-3 different technical approaches with trade-offs
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended option and explain why
- Apply YAGNI ruthlessly - remove unnecessary features

**For STORY/INVESTIGATION:**
- Propose 2-3 different narrative frames with trade-offs:
  - Personal essay (intimate, limited scope, accessible)
  - Investigative feature (rigorous, broad, requires extensive sourcing)
  - Hybrid narrative investigation (personal entry point, systemic analysis)
- Present options conversationally with your recommendation
- Lead with your recommended approach and explain why

### Presenting the Concept

**For CODE (design):**
- Once you understand what you're building, present the design
- Break it into sections of 200-300 words
- Ask after each section whether it looks right so far
- Cover: architecture, components, data flow, error handling, testing
- Be ready to go back and clarify if something doesn't make sense

**For STORY/INVESTIGATION (prospectus):**
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

## After Validation

### For CODE Development

**Documentation:**
- Write the validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md`
- Use elements-of-style:writing-clearly-and-concisely skill if available
- Commit the design document to git

**Implementation handoff:**
- Ask: "Ready to set up for implementation?"
- Use superpowers:using-git-worktrees to create isolated workspace
- Use superpowers:writing-plans to create detailed implementation plan

### For STORY/INVESTIGATION

**Documentation:**
- Write the validated prospectus to `writing/prospectuses/YYYY-MM-DD-<story-slug>.md`
- Commit the prospectus (or save with timestamp if not using git)

**Research planning handoff:**
- Ask: "Ready to plan the research and drafting process?"
- Use narrative:story-plan to create detailed research and writing plan
- Consider which specialist agents to invoke: Archivist, Analyst, Ethicist, Narrator, Skeptic, Community Listener

## Key Principles

**Universal (both paths):**
- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **Explore alternatives** - Always propose 2-3 approaches before settling
- **Incremental validation** - Present concept in sections, validate each
- **Be flexible** - Go back and clarify when something doesn't make sense

**Code-specific:**
- **YAGNI ruthlessly** - Remove unnecessary features from all designs

**Story-specific:**
- **Personal → Structural** - Start with lived experience, zoom out to systems
- **Ethics first** - Always consider who might be harmed
- **Sources before claims** - Identify research gaps explicitly
- **Writer as investigator** - Not omniscient narrator, but curious witness
