# Agents Directory - DEPRECATED

**Note:** This directory contains legacy agent definitions. Agent prompts have been moved to their respective skill directories following the established pattern.

## Current Agent Locations

### Code Development Agents
- **Code Reviewer**: `skills/requesting-code-review/code-reviewer.md`
- **Implementer**: `skills/subagent-driven-development/implementer-prompt.md`
- **Spec Reviewer**: `skills/subagent-driven-development/spec-reviewer-prompt.md`
- **Code Quality Reviewer**: `skills/subagent-driven-development/code-quality-reviewer-prompt.md`

### Narrative Investigation Agents
- **Archivist**: `skills/evidence-driven-drafting/archivist-prompt.md`
- **Analyst**: `skills/evidence-driven-drafting/analyst-prompt.md`
- **Ethicist**: `skills/evidence-driven-drafting/ethicist-prompt.md`
- **Narrator**: `skills/evidence-driven-drafting/narrator-prompt.md`
- **Skeptic**: `skills/evidence-driven-drafting/skeptic-prompt.md`
- **Community Listener**: `skills/evidence-driven-drafting/community-listener-prompt.md`
- **Fact Checker**: `skills/evidence-driven-drafting/fact-checker-prompt.md`
- **Ethical Reviewer**: `skills/evidence-driven-drafting/ethical-reviewer-prompt.md`

## Architecture Pattern

Agent prompts belong **inside the skill directory** that uses them, following this pattern:

```
skills/
  skill-name/
    SKILL.md              # Main skill workflow
    agent-name-prompt.md  # Subagent prompts used by this skill
```

This ensures:
- Agent prompts are versioned with the skill
- Skills are self-contained and portable
- Clear ownership and discoverability
- Follows established pattern from subagent-driven-development

## Migration Status

The files in this directory can be safely removed once confirmed that all references point to the new locations in skill directories.
