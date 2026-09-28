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

## Commit gate (mandatory)
```bash
bash scripts/check-project.sh <project> --run-tests --run-lint
```
Exit code 1 = commit refused: failing test, failing lint/type check, possible secret or tracked `.env`. Fix, re-run, then commit. Never bypass it (`--no-verify`, skipping or weakening tests, editing linter config).
Projects can declare their exact checks in `.siska/checks` (one shell command per line, run from the root; optional `front:` / `back:` / `mobile:` prefix); it replaces auto-detection.
`--scope front,back,mobile` checks only those parts while working; the commit gate always checks everything.
Claude Code: the plugin hook runs this gate automatically on every `git commit` and blocks it on failure.

## Before commit / PR
```bash
git status
git diff            # unstaged
git diff --staged   # staged
```
Check: every hunk is needed · no secret (`.env`, keys, tokens) · no debug output · no generated/build files · migrations and lockfiles intended.

Commit, push or open a PR only when the user asks.
