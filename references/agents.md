# Tools, sub-agents and token economy

## Tools, skills and MCP
Before a complex task, list the skills, tools, MCP servers and connectors available. Use the ones that reduce risk or verify the result (planning, debugging, code review, security review, browser QA, framework docs, design, humanizer for docs and PR text). Do not reimplement what a tool already does; do not use a tool just to use it. Agent-specific mappings: `compat/` (e.g. `compat/claude-code.md`).

## Sub-agents (when the agent can run them)
Use them for work that would flood the main context or can run in parallel: broad code search, reading many files, independent audits, a domain split (backend / frontend / QA-security) followed by a lead review.
- One precise task each; ask for a short conclusion, not file dumps.
- Smaller/cheaper model for simple search or summary tasks when the agent allows it.
- Not for a task you can finish with a few direct reads or edits.

## Token economy
- Load only the references the task needs.
- Search (grep/glob) before reading; read the relevant part of a file, not the whole file.
- Never re-read what is already known.
- Run a command once; keep only the useful lines of its output.
- Short answers: result first, details only when asked.
