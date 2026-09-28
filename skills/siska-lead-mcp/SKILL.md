---
name: siska-lead-mcp
description: Use when the user invokes /siska-lead-mcp or asks to add, extend, secure or audit an MCP (Model Context Protocol) server in an existing application or a new project - MCP tools, MCP OAuth, MCP permissions/scopes, MCP client configuration.
---

# /siska-lead-mcp

Entry point of the **siska-lead-developer** skill for MCP work.

1. Load the `siska-lead-developer` skill and apply all its rules (zero regression, never invent, exact scope, security first).
2. Follow its `references/mcp.md` step by step (17 steps), using its `templates/mcp/` and `scripts/`.
3. Stop and ask the user at step 7 for every missing decision; never assume which capabilities, scopes or authorization server to use.
