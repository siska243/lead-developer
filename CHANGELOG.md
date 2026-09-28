# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [1.1.0] - 2026-09-28
### Added
- Claude Code plugin (`.claude-plugin/`) with commands `:help`, `:audit-route [--filter]`, `:audit-package [--outdated]`, `:mcp`.
### Changed
- `siska-lead-mcp` replaced by `/siska-lead-developer:mcp`; `install.sh` now installs the main skill only (other agents) and still removes the old entry on `--uninstall`.
- README shortened.

## [1.0.0] - 2026-09-28
### Added
- `SKILL.md`: Lead Developer identity, priorities, absolute rules, workflow, reference loading, tools/team mode, red flags.
- References: workflow, TMA, new project, clean code, git, security, dependencies, testing, performance, design system, UX, motion design, MCP.
- Scripts: `detect-stack.sh`, `security-audit.sh`, `check-project.sh`, `install.sh`, shared `lib.sh`, self-tests.
- MCP templates: TypeScript server (stdio + stateless Streamable HTTP, OAuth resource server, scope-checked tool, tests), OAuth guide, client config.
- `siska-lead-mcp` entry skill and `compat/claude-code.md`.
- `install.sh --uninstall`: removes only symlinks or directories declaring the expected skill name; keeps backups.
