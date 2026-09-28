---
name: mcp
description: Use when adding, extending, securing or auditing an MCP (Model Context Protocol) server in an existing application or a new project - MCP tools, MCP OAuth, MCP permissions/scopes, MCP client configuration.
argument-hint: "[what to expose]"
---

Arguments: `$ARGUMENTS`

1. Apply all rules of `${CLAUDE_SKILL_DIR}/../../SKILL.md` (zero regression, never invent, exact scope, security first).
2. Follow `${CLAUDE_SKILL_DIR}/../../references/mcp.md` step by step (17 steps), with `${CLAUDE_SKILL_DIR}/../../templates/mcp/` and `${CLAUDE_SKILL_DIR}/../../scripts/`.
3. At step 7, ask the user every missing decision (capabilities, scopes, authorization server); never assume.
