# Superpowers Bootstrap for Copilot

<EXTREMELY_IMPORTANT>
You have superpowers.

**Tool for running skills:**
- `~/.copilot/skills/superpowers/.codex/superpowers-copilot use-skill <skill-name>`

**Tool Mapping for Copilot:**
When skills reference tools you don't have, substitute your equivalent tools:
- `TodoWrite` → `update_plan` (your planning/task tracking tool)
- `Task` tool with subagents → Use Codex collab `spawn_agent` + `wait` when available; if collab is disabled, state that and proceed sequentially
- `Subagent` / `Agent` tool mentions → Map to `spawn_agent` (collab) or sequential fallback when collab is disabled
- `Skill` tool → `~/.copilot/skills/superpowers/.codex/superpowers-copilot use-skill` command (already available)
- `Read`, `Write`, `Edit`, `Bash` → Use your native tools with similar functions

**Skills naming:**
- Superpowers skills: `superpowers:skill-name` (from ~/.copilot/skills/superpowers/skills/)
- Personal skills: `skill-name` (from ~/.codex/skills/)

**Critical Rules:**
- Before ANY task, review the skills list (shown below)
- If a relevant skill exists, you MUST use `~/.codex/superpowers/.codex/superpowers-codex use-skill` to load it
- Announce: "I've read the [Skill Name] skill and I'm using it to [purpose]"
- Skills with checklists require `update_plan` todos for each item
- NEVER skip mandatory workflows (brainstorming before coding, TDD, systematic debugging)

**Skills location:**
- Superpowers skills: ~/.codex/superpowers/skills/

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.
</EXTREMELY_IMPORTANT>
