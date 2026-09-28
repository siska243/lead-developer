# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [1.7.0] - 2026-09-28
### Added
- Commands for every Skills-compatible agent: `install.sh` generates `siska-audit-route`, `siska-check-code`, `siska-document`, `siska-skills`, `siska-tickets`, `siska-mcp`, `siska-help` with absolute paths and standard frontmatter only (recognized for Codex, GitHub Copilot, OpenCode).
- `scripts/install-git-hook.sh`: native git pre-commit commit gate for any agent; never overwrites an existing hook or hook manager; harmless if the skill is later removed.
- `compat/README.md`: install, skills directory, command call and commit gate per agent.
### Changed
- Commit gate message no longer names one agent.

## [1.6.0] - 2026-09-28
### Added
- Skill and MCP orchestration (`references/orchestration.md`): needed capabilities → installed → search (skills.sh, agent marketplaces, official MCP Registry) → vetting → consent → install; refusal is final; Siska's rules override any skill.
- `scripts/list-capabilities.sh`: skills and MCP servers installed for AI coding agents (skill dirs, plugins, MCP configs).
- `scripts/vet-skill.sh`: static security review of a skill/plugin before install (scripts, hooks, MCP servers, allowed-tools, network, secrets, destructive or hidden instructions).
- `/siska-lead-developer:skills [list|find|vet|install]`.
- High-risk action rule: impact and rollback, explicit confirmation, or refusal.

## [1.5.0] - 2026-09-28
### Added
- Mandatory feature documentation (`references/documentation.md`): functional page, then technical (API calls, data, jobs, security), verified against the code, human-sounding; part of the delivery checklist.
- `/siska-lead-developer:document [--functional|--api|--code]`.
- OpenAPI guidance per stack (FastAPI, Scramble/Scribe, API Platform/Nelmio, @nestjs/swagger, swagger-jsdoc) and spec lint with `@redocly/cli`.

## [1.4.0] - 2026-09-28
### Added
- Commit gate: plugin `PreToolUse` hook runs `scripts/pre-commit-gate.sh` on every `git commit` and blocks it when tests, lint, secret or `.env` checks fail.
- `/siska-lead-developer:check-code` command.
- `check-project.sh --run-lint`: Pint, PHPStan, `composer lint`, npm `lint`/`typecheck` scripts, Ruff.
- `.siska/checks`: project-declared check commands, replacing auto-detection.
- `check-project.sh --scope front,back,mobile` and `check-code --front/--back/--mobile`; `.siska/checks` lines can be tagged `front:` / `back:` / `mobile:`; a scope with no command is reported as not verified.

## [1.3.0] - 2026-09-28
### Added
- Request ledger (`references/requests.md`): every request gets an ID (T1…), priority (P1–P3) and status (todo, in progress, done, needs info, cancelled), stored in `.siska/requests.md`; duplicate check before redoing a done request; `t<n>` messages update a ticket; summary table at the end of each response.
- `/siska-lead-developer:tickets` command to show or update tickets.
- Uniformity rules: one way to do one thing, project linters/formatters on changed files, no second library for the same job.
- Design system applied to the letter: tokens only, one component per purpose, same pattern for the same interaction.
- Human-sounding writing for comments, docs, commits, PR and UI copy (humanizer skill when available).
- Plain-language explanation of the plan before acting.
- Sub-agent guidance (when they save context or run in parallel, cheaper models for simple tasks) and token economy rules.
### Changed
- `SKILL.md` condensed from ~1150 to ~600 words; tools, sub-agents and token rules moved to `references/agents.md`.

## [1.2.0] - 2026-09-28
### Added
- `audit-package`: maintenance status of direct dependencies (deprecated, abandoned, archived, stale) and unused dependency detection (knip, composer-unused, deptry) with removal only after approval.
- `security-audit.sh`: reports abandoned Composer packages (Composer >= 2.7).

## [1.1.1] - 2026-09-28
### Fixed
- `install.sh` refuses to install a copy into `.claude/skills` when the Claude Code plugin is installed.
### Changed
- README: `/plugin` install/uninstall steps and the marketplace source conflict error.

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
