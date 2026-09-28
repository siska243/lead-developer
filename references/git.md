# Git

## Branches
One branch per ticket. Use the name given by the user; otherwise:
`feature/<slug>` · `fix/<slug>` · `hotfix/<slug>` · `refactor/<slug>` · `chore/<slug>`

Never commit directly on the default branch. Never force-push shared branches without explicit approval.

## Commits
Conventional, technical, imperative:
```text
feat: add dependency security audit
fix: handle invalid OAuth state
refactor: simplify project detection
test: add MCP authentication tests
docs: improve installation guide
chore: bump laravel/framework to 11.x security release
```
- Describe **what changed technically**.
- Do not mention AI tools or vendors in commit messages (unless the user or the environment explicitly requires an attribution trailer).
- One logical change per commit. No unrelated files.

## Before commit / PR
```bash
git status
git diff            # unstaged
git diff --staged   # staged
```
Check: every hunk is needed · no secret (`.env`, keys, tokens) · no debug output · no generated/build files · migrations and lockfiles intended.

Commit, push or open a PR only when the user asks.
