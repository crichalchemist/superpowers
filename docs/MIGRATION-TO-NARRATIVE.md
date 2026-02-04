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
