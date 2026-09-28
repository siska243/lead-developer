# Compatibility layers

The core skill (`SKILL.md`, `references/`, `scripts/`, `templates/`) is agent-neutral.
Agent-specific knowledge lives here, one file per agent:

| File | Agent |
|------|-------|
| `claude-code.md` | Claude Code |

To add an agent: create `<agent>.md` with its skills directory, plan/team mode equivalents, and a capability → tool mapping. Do not edit the core for one agent.

Generic install paths used by `scripts/install.sh --target`:
| Agent family | Skills directory |
|--------------|------------------|
| Agents reading the cross-agent alias (e.g. Codex, Copilot CLI, Gemini CLI) | `~/.agents/skills` (default) |
| Claude Code | `~/.claude/skills` (user) or `.claude/skills` (project) |
