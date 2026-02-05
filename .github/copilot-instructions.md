# Copilot Instructions for Superpowers

## Architecture

**Superpowers is a Claude Code plugin** that provides complete workflows for software development AND investigative/creative non-fiction writing, built on composable "skills" - self-contained workflow patterns that trigger automatically based on context.

**Core components:**
- **Skills** (`skills/*/SKILL.md`): YAML frontmatter + workflow instructions. Personal skills (`~/.claude/skills`) shadow plugin skills. Use namespace prefixes (`superpowers:`, `narrative:`) to force plugin version.
- **Commands** (`commands/*.md`): User-facing slash commands (e.g., `/superpowers:brainstorm`, `/narrative:interrogate`) that invoke skills.
- **Agents** (`agents/*.md`): Specialized subagent prompts for code review, investigation, etc.
- **Hooks** (`hooks/session-start.sh`): Injects `using-superpowers` skill into every Claude Code session via JSON output.
- **Library** (`lib/skills-core.js`): Skill discovery, frontmatter parsing, path resolution, and namespace handling.

**Dual-mode operation:**
- **Dev mode**: Plans in `docs/plans/`, tests in code repos, commits tracked in git
- **Writing mode**: Prospectuses in `writing/prospectuses/`, research in `writing/source-notes/`, drafts in `writing/drafts/`, plans in `writing/plans/`
- Both modes use the same skill architecture and subagent orchestration patterns

**Skill invocation flow:** Session starts → `hooks/session-start.sh` runs → injects skill descriptions → Claude matches trigger conditions → uses Skill tool → follows instructions exactly.

## Critical Patterns

### Skill Structure (REQUIRED for all skills)

```markdown
---
name: skill-name-with-hyphens
description: Use when [trigger condition] - [brief action]
---

# Skill Content
[Workflow instructions, decision trees, checklists]
```

**Frontmatter rules:**
- Only `name` and `description` fields supported (max 1024 chars total)
- `name`: letters, numbers, hyphens only (no parentheses/special chars)
- `description`: Third-person, focus on WHEN to use (not what it does)

**Namespace prefixes:**
- `superpowers:skill-name` forces plugin development skills (e.g., `superpowers:brainstorming`)
- `narrative:skill-name` forces plugin narrative skills (e.g., `narrative:interrogate`)
- Bare `skill-name` uses personal skills if they exist, falls back to plugin
- Skills reference other skills with namespace prefixes to ensure correct version

### Test-Driven Development (TDD) Philosophy

**Everything follows RED-GREEN-REFACTOR:**
- Skills: Write pressure scenarios (RED) → verify agent fails → write skill (GREEN) → close loopholes (REFACTOR)
- Code: Write failing test → watch it fail → minimal code → watch it pass → refactor
- Writing: Make claim (CLAIM) → verify sources (CHECK) → strengthen or qualify (REVISE)
- **No production code without failing test first.** Code written before tests gets deleted.
- **No claims without sources.** Unsourced assertions must be flagged `[INFERENCE - NEEDS VERIFICATION]`.

Key principles: YAGNI (You Aren't Gonna Need It), DRY (Don't Repeat Yourself), 2-5 minute tasks.

### Plan-Based Workflows

**Unified entry:** `brainstorming` asks "code or story?" then adapts its process accordingly.

**Plan-based development workflow:**
1. `brainstorming` (CODE) → Refine technical design through questions, present in 200-300 word sections
2. `using-git-worktrees` → Create isolated branch workspace
3. `writing-plans` → Break into 2-5 minute tasks with exact file paths in `docs/plans/YYYY-MM-DD-<topic>-{design,implementation}.md`
4. `subagent-driven-development` OR `executing-plans` → Implement with review loops
5. `test-driven-development` → RED-GREEN-REFACTOR enforced
6. `requesting-code-review` → Verify against plan
7. `finishing-a-development-branch` → Merge/PR workflow

**Narrative investigation workflow:**
1. `brainstorming` (STORY) → Refine narrative prospectus through Socratic questions, present in 200-300 word sections
2. `narrative:story-plan` → Break into research/drafting tasks in `writing/plans/YYYY-MM-DD-<story>.md`
3. `narrative:evidence-driven-drafting` → Dispatch specialist agents (Archivist, Analyst, Ethicist, Narrator, Skeptic, Community Listener)
4. `narrative:fact-check-driven-revision` → CLAIM-CHECK-REVISE enforced (parallel to TDD for claims)
5. Outputs saved to `writing/{prospectuses,source-notes,drafts}/`

**Workflow parallels:**
| Development | Investigation | Core Principle |
|-------------|---------------|----------------|
| TDD (test first) | Fact-check-driven (source first) | Verification before claims |
| Code reviewer | Fact-checker + Ethical reviewer | Independent verification |
| Implementer | Archivist/Analyst/Narrator | Task specialist |
| Plan = contract | Plan = contract | No deviation without update |

**Plans are contracts** - implementation/writing must match plan or update plan first.

### Subagent Orchestration

**Code development** (`subagent-driven-development`) dispatches fresh subagents per task with two-stage review:
1. **Implementer** (Task tool): Implements, tests, commits, self-reviews
2. **Spec Reviewer** (Task tool): Verifies code matches plan (reads code independently)
3. **Code Quality Reviewer** (Task tool): Reviews code quality

**Narrative investigation** (`evidence-driven-drafting`) dispatches specialist agents by expertise:
- **Archivist**: Historical records, archives, public documents (uses Graph of Thoughts methodology)
- **Analyst**: Data analysis, financial flows, pattern recognition
- **Ethicist**: Harm assessment, positionality, ethical considerations
- **Narrator**: Storytelling, narrative structure, voice
- **Skeptic**: Claims verification, logical fallacies, counterarguments
- **Community Listener**: Missing voices, power dynamics, community impact
- **Fact-Checker**: Source verification, citation accuracy, claim validation

Each subagent gets:
- Fresh context (no conversation history)
- Specific prompt from skill directory (e.g., `implementer-prompt.md`, `archivist-prompt.md`)
- Complete task description (not file references)

## Testing

**Integration tests** (`tests/claude-code/*.sh`):
- Parse session transcripts (`.jsonl` files) not terminal output
- Use `--permission-mode bypassPermissions` for headless testing
- **Must run from superpowers plugin directory** (not temp dirs)
- Require `"superpowers@superpowers-dev": true` in `~/.claude/settings.json`

**Key test:** `test-subagent-driven-development-integration.sh` - verifies full plan execution with multiple subagents (10-30 min runtime).

**Token analysis:** After any session: `python3 tests/claude-code/analyze-token-usage.py ~/.claude/projects/<encoded-path>/<session-id>.jsonl`

## Development Commands

```bash
# Session transcripts location (for debugging)
~/.claude/projects/-{working-directory-with-slashes-as-hyphens}/

# Install local dev version
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace

# Run integration tests (from plugin root)
cd tests/claude-code
./test-subagent-driven-development-integration.sh
```

## Key Conventions

- **Skills are mandatory workflows**, not suggestions - must be followed exactly
- **Never skip skill checks** - before ANY work, check if a skill applies
- **Verification before claims** - run verification commands before declaring success
- **Personal vs plugin skills** - personal skills shadow plugin by default, use `superpowers:` or `narrative:` prefix to force plugin version
- **Every claim needs a source** - unsourced assertions get flagged `[INFERENCE]` or qualified with uncertainty language
- **Fresh agents per task** - no context pollution between implementation/research tasks

## Cross-Platform Support

- **Claude Code**: Primary platform (uses `plugin.json`, hooks)
- **Codex**: See `.codex/INSTALL.md` and `docs/README.codex.md`
- **OpenCode**: See `.opencode/INSTALL.md` and `docs/README.opencode.md`

## Creating New Skills

**Follow `skills/writing-skills/SKILL.md`:**
1. Run baseline pressure scenario with subagent (RED - watch it fail)
2. Write skill addressing specific violations (GREEN)
3. Close loopholes while maintaining compliance (REFACTOR)
4. Include YAML frontmatter with `name` and `description`
5. Test with actual subagent workflows before committing

See `skills/writing-skills/anthropic-best-practices.md` for official Anthropic guidance.
