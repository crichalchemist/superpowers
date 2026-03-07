# Superpowers Style Guide for Gemini Code Assist

This repository provides dual-mode skills for AI coding assistants: software development (TDD, debugging, code review) and investigative journalism (evidence-driven drafting, fact-checking, ethical review).

## Skill Structure

All skills live in `skills/*/SKILL.md` with YAML frontmatter:

```markdown
---
name: skill-name-with-hyphens
description: Use when [trigger condition] - [brief action]
---

# Skill Content
[Workflow instructions, decision trees, checklists]
```

### Frontmatter Rules
- Only `name` and `description` fields (max 1024 chars total)
- `name`: letters, numbers, hyphens only
- `description`: Third-person, focus on WHEN to use

### Namespace
- All skills use the `superpowers:` prefix (e.g., `superpowers:interrogate`)
- Never use `narrative:` prefix — it does not resolve

## Dual-Mode Workflows

### Code Development
1. `brainstorming` → Refine technical design
2. `writing-plans` → Break into 2-5 minute tasks
3. `subagent-driven-development` → Implement with review loops
4. `test-driven-development` → RED-GREEN-REFACTOR enforced

### Investigative Writing
1. `superpowers:interrogate` → Develop story prospectus
2. `superpowers:story-plan` → Research and drafting plan
3. `superpowers:evidence-driven-drafting` → Dispatch specialist agents
4. `superpowers:fact-check-driven-revision` → CLAIM-CHECK-REVISE enforced

## Voice Context

Writing personality files live at `.github/writing-personality/` (not `skills/writing-personality/`). The Narrator agent references these for authentic voice during drafting.

## Key Conventions

- Skills are mandatory workflows, not suggestions
- Verification before claims — test code, source assertions
- Plans are contracts — implementation must match plan or update plan first
- Every claim needs a source — unsourced assertions get flagged `[INFERENCE]`
- Fresh agents per task — no context pollution between tasks
