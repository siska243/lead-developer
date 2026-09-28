# Claude Code compatibility

Install as a plugin (see README): `claude plugin marketplace add <repo or path>` then
`claude plugin install siska-lead-developer@siska`. Commands: `/siska-lead-developer:help`.
The plugin manifest (`.claude-plugin/`) and the command skills (`skills/`) are this compatibility layer;
they use `${CLAUDE_SKILL_DIR}` to reach the core files.

## Native capabilities
| Skill need | Claude Code |
|------------|-------------|
| Plan mode | `EnterPlanMode` / `ExitPlanMode` for any non-trivial task |
| Team mode | `Agent` tool: `Explore` (read-only search), `Plan` (architecture), `general-purpose` (implementation); run independent agents in parallel |
| Isolation | `EnterWorktree` / `isolation: "worktree"` for risky or parallel work |
| Ask user | `AskUserQuestion` for decisions that belong to the user |
| Framework docs | `WebFetch` / `WebSearch` on official docs for the installed version |

## Skills to use when installed (check the session's skill list first; skip those absent)
| Workflow step | Skills |
|---------------|--------|
| Understand / design a feature | `superpowers:brainstorming`, `office-hours` |
| Plan | `superpowers:writing-plans`, `plan-eng-review`, `plan-design-review`, `autoplan` |
| Explore a codebase | `graphify` (knowledge graph), `claude-mem:smart-explore`, `claude-mem:mem-search` (past work) |
| Implement | `superpowers:test-driven-development`, `superpowers:executing-plans`, `superpowers:subagent-driven-development` |
| Debug / TMA | `superpowers:systematic-debugging`, `investigate` |
| Protect production | `careful`, `guard`, `freeze` (block destructive commands / scope edits) |
| Security | `security-review`, `cso` |
| Review the diff | `code-review`, `review`, `simplify`, `superpowers:requesting-code-review` |
| Verify | `superpowers:verification-before-completion`, `qa` / `qa-only`, `browse` (real browser), `health`, `benchmark` |
| UI / UX / design system | `impeccable`, `ui-ux-pro-max:ui-ux-pro-max`, `frontend-design:frontend-design`, `design-consultation`, `design-review`, `emil-design-eng`, `apple-design`, `mobile-native` |
| Motion design | `animate` (web), `animate-expo` (React Native), `review-animations`, `improve-animations`, `find-animation-opportunities`, `remotion` |
| Expo / React Native | `expo:*` skills (`expo:expo-router`, `expo:expo-upgrade`, `expo:expo-ui`, `expo:eas-*`…) |
| Monitoring | `sentry-cli` |
| Delivery | `superpowers:finishing-a-development-branch`, `ship` |

## MCP servers (when connected)
| Need | MCP |
|------|-----|
| Remotion documentation | `remotion` (`remotion-documentation`) |
| Expo / EAS | `expo` plugin MCP |
| Past sessions memory | `claude-mem` (`search`, `smart_search`, `timeline`) |
| Tickets / docs | Linear, Atlassian (Jira/Confluence), Notion, Asana, monday.com connectors |
| Design source | Figma, Canva connectors |
| GitHub PRs / issues | `github` plugin MCP or the `gh` CLI |

A connector that failed to connect is a connection problem: tell the user, do not conclude it does not exist.
