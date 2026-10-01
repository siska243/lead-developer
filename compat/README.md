# Compatibility layers

The core skill (`SKILL.md`, `references/`, `scripts/`, `templates/`) is agent-neutral.
Agent-specific details live here.

| Agent | Install | Skills directory | Call a command | Commit gate |
|-------|---------|------------------|----------------|-------------|
| Claude Code | plugin (`/plugin install siska-lead-developer@siska`) | plugin | `/siska-lead-developer:check-code` | plugin hook (automatic) |
| Codex | `bash scripts/install.sh` | `~/.agents/skills`, repo `.agents/skills` | `$siska-check-code` or `/skills` | `bash scripts/install-git-hook.sh <project>` |
| GitHub Copilot | `bash scripts/install.sh` | `~/.agents/skills`, `~/.copilot/skills`, repo `.github/skills` / `.agents/skills` | select or mention `siska-check-code` | `bash scripts/install-git-hook.sh <project>` |
| OpenCode and other agents reading `~/.agents/skills` | `bash scripts/install.sh` | `~/.agents/skills` | the agent's way to call a skill by name | `bash scripts/install-git-hook.sh <project>` |
| Any other Skills-compatible agent | `bash scripts/install.sh --target <its skills dir>` | its own | its own | `bash scripts/install-git-hook.sh <project>` |

## What each agent gets

| Feature | Claude Code (plugin) | Codex, Copilot, OpenCode, others (`install.sh`) |
|---------|----------------------|--------------------------------------------------|
| Rules, references, every command (`siska-optimize`, `siska-api-docs`, `siska-data-model`…) | yes | yes (generated, absolute paths) |
| Scripts (scans, budgets, API docs, data model, reports) | yes | yes: plain bash and Node, also usable by hand |
| Commit gate: tests, lint, secret scan, AI attribution | plugin hook | git hooks `pre-commit` + `commit-msg` (`install-git-hook.sh`) |
| Visual reports, API docs page, data model explorer | shared rich page (artifact) + files | HTML files to open (`report.sh --standalone`, `docs/`) |
| Request ledger (T1, T2…) enforced on every message | yes (session hooks) | rule followed by the agent, not enforced |
| Micro-task mode (`settings micro on`) | reminder injected on every message | the agent reads `micro-tasks` in `.siska/settings` (rule in `SKILL.md`) |
| Update | `claude plugin marketplace update siska` + `claude plugin update siska-lead-developer@siska` | `git pull` + `bash scripts/install.sh --force` (commands are regenerated) |
| Disable / enable | `claude plugin disable|enable siska-lead-developer@siska` | the agent's own skill settings if any, else `install.sh --uninstall` / reinstall |

`install.sh` generates the commands (`siska-audit-route`, `siska-check-code`, …) from `skills/` with absolute paths and without agent-specific placeholders, so they run in any agent. The git hooks block every commit in that repository (agent or human) when the checks or the secret scan fail (`pre-commit`), or when the message carries an AI co-author trailer (`commit-msg`).

Request ledger enforcement (reminder on each message, response blocked until `.siska/requests.md` is updated) needs prompt/stop hooks: Claude Code plugin only. Other agents follow the rule in `references/requests.md` without enforcement.

To add an agent: add a row here (and a `<agent>.md` file if it needs more than a row). Do not edit the core for one agent.
