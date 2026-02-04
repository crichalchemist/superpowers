# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

Superpowers is a Claude Code plugin that provides a complete software development workflow built on composable "skills" - reusable workflow patterns that guide Claude through processes like brainstorming, planning, testing, and code review.

### Core Components

- **Skills** (`skills/*/SKILL.md`): Self-contained workflow patterns with YAML frontmatter (name, description) that define processes. Skills automatically trigger based on context. Personal skills in `~/.claude/skills` override plugin skills.

- **Commands** (`commands/*.md`): User-facing slash commands (e.g., `/superpowers:brainstorm`) that invoke skills with pre-defined instructions.

- **Agents** (`agents/*.md`): Specialized subagent definitions (e.g., `code-reviewer`) with their own prompts and focus areas. Invoked via the Task tool.

- **Hooks** (`hooks/`): Session lifecycle hooks that inject skill content. `session-start.sh` loads `using-superpowers` skill into every session.

- **Library** (`lib/skills-core.js`): Core skill discovery, resolution, and frontmatter parsing. Handles skill shadowing (personal > plugin) and namespace resolution (`superpowers:` prefix).

### Skill Structure

Skills follow a consistent pattern:
```markdown
---
name: skill-name
description: Use when [trigger condition] - [what it does]
---

# Skill Content

[Workflow instructions, decision trees, checklists]
```

Skills can reference other skills, spawn subagents via Task tool, and include supporting documentation in the same directory.

## Development Commands

### Running Tests

```bash
# Integration tests (require Claude Code CLI and can take 10-30 minutes)
cd tests/claude-code
./test-subagent-driven-development-integration.sh

# Skill triggering tests
cd tests/skill-triggering
./run-all.sh

# OpenCode compatibility tests
cd tests/opencode
./run-tests.sh
```

**Important**: Integration tests must run FROM the superpowers plugin directory (not from temp dirs) with the dev marketplace enabled in `~/.claude/settings.json`:
```json
{
  "enabledPlugins": {
    "superpowers@superpowers-dev": true
  }
}
```

### Analyzing Token Usage

After any Claude Code session:
```bash
python3 tests/claude-code/analyze-token-usage.py ~/.claude/projects/<encoded-path>/<session-id>.jsonl
```

Session files are stored at: `~/.claude/projects/-{working-directory-with-slashes-as-hyphens}/`

### Plugin Development

```bash
# Install local development version
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace

# Update plugin after changes
/plugin update superpowers
```

## Key Workflows

### Creating New Skills

Follow `skills/writing-skills/SKILL.md` which includes:
- YAML frontmatter requirements
- Testing methodology with subagents
- Anthropic best practices for prompt engineering
- Anti-patterns to avoid

New skills must:
1. Include frontmatter with `name` and `description`
2. Define clear trigger conditions in description
3. Be tested with actual subagent workflows before committing
4. Follow the persuasion principles in `skills/writing-skills/persuasion-principles.md`

### Testing Skills with Subagents

See `docs/testing.md` for comprehensive testing guide. Key points:

- Tests parse session transcripts (`.jsonl` files) not terminal output
- Use `--permission-mode bypassPermissions` for headless testing
- Session transcripts contain token usage per subagent
- Tests verify actual behavior: files created, tests passing, commits made

### Skill Resolution and Shadowing

Personal skills (`~/.claude/skills/`) override plugin skills. Use `superpowers:` prefix to force plugin version:
- `brainstorming` → checks personal first, then plugin
- `superpowers:brainstorming` → always uses plugin version

Resolution handled by `lib/skills-core.js` `resolveSkillPath()`.

## Architecture Patterns

### Skill Invocation Flow

1. Session starts → `hooks/session-start.sh` runs
2. Hook injects `using-superpowers` content into system prompt
3. Claude sees skill descriptions and trigger conditions
4. When conditions match, Claude invokes skill via Skill tool
5. Skill content is loaded and presented to Claude
6. Claude follows skill instructions exactly

### Subagent Workflows

Skills like `subagent-driven-development` orchestrate multiple agents:

1. **Coordinator** (main Claude): Reads plan, dispatches tasks
2. **Implementers** (Task tool subagents): Write code following task specs
3. **Spec Reviewers** (Task tool subagents): Verify implementation matches plan
4. **Code Quality Reviewers** (Task tool subagents): Review code quality

Each subagent gets:
- Fresh context (no conversation history)
- Specific prompt from skill (e.g., `implementer-prompt.md`)
- Complete task description (not file references)
- Access to prompt caching for efficiency

### Plan-Based Development

The full workflow through code completion:

1. **brainstorming** → Refine idea through questions, present design in sections
2. **using-git-worktrees** → Create isolated branch and workspace
3. **writing-plans** → Break work into 2-5 minute tasks with exact file paths
4. **subagent-driven-development** OR **executing-plans** → Implement with review loops
5. **test-driven-development** → RED-GREEN-REFACTOR cycle enforced
6. **requesting-code-review** → Verify against plan before merging
7. **finishing-a-development-branch** → Merge/PR decision workflow

Plans go in `docs/plans/YYYY-MM-DD-<topic>-{design,implementation}.md`

## Important Conventions

- **Never skip skill checks**: Before ANY work, check if a skill applies (even 1% chance)
- **Skills are mandatory workflows**: Not suggestions - must be followed exactly
- **Test-first always**: TDD is enforced, code written before tests gets deleted
- **Verification before claims**: Run verification commands before declaring success
- **Plans are contracts**: Implementation must match plan or update plan first
- **Personal vs plugin skills**: Personal skills shadow plugin skills by default

## Session Start Hook

The `hooks/session-start.sh` does critical setup:

1. Checks for legacy `~/.config/superpowers/skills` and warns user
2. Reads `skills/using-superpowers/SKILL.md` content
3. Injects it into system prompt as `<EXTREMELY_IMPORTANT>` section
4. Escapes content for JSON output
5. Returns `hookSpecificOutput` with `additionalContext`

This ensures every Claude Code session automatically knows about Superpowers skills and how to use them.

## Cross-Platform Compatibility

- **Claude Code**: Primary platform, uses plugin.json and hooks
- **Codex**: See `.codex/INSTALL.md` and `docs/README.codex.md`
- **OpenCode**: See `.opencode/INSTALL.md` and `docs/README.opencode.md`
- **Windows**: Polyglot hooks in `docs/windows/polyglot-hooks.md`

Each platform has different skill loading mechanisms but shares the same skill content.

## Philosophy and Design Principles

From README and skills:

- **Test-Driven Development**: Write tests first, always
- **Systematic over ad-hoc**: Process over guessing
- **Complexity reduction**: Simplicity as primary goal
- **Evidence over claims**: Verify before declaring success
- **2-5 minute tasks**: Keep tasks small and focused
- **YAGNI**: You Aren't Gonna Need It - no premature features
- **DRY**: Don't Repeat Yourself

## Future Direction

Note: `context.md` contains experimental ideas for narrative/investigative writing workflows - this represents future exploration, not current implementation. The current codebase remains focused on software development workflows.