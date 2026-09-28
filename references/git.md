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
Exit code 1 = commit refused: failing test, failing lint/type check, possible secret or tracked `.env`. Fix, re-run, then commit. Never bypass it on your own (`--no-verify`, `SISKA_SKIP_GATE=1`, skipping or weakening tests, editing linter config).
**Skip only when the user explicitly asks for it in the current message** ("skip the check for this commit"): commit with `SISKA_SKIP_GATE=1 git commit …`, and say in the report that the checks were skipped and which ones were failing.
Projects can declare their exact checks in `.siska/checks` (one shell command per line, run from the root; optional `front:` / `back:` / `mobile:` prefix); it replaces auto-detection.
`--scope front,back,mobile` checks only those parts while working; the commit gate always checks everything.
Enforcement: the Claude Code plugin hook runs this gate on every `git commit`; for any other agent (and for human commits) install the git hook: `bash scripts/install-git-hook.sh <project>` (never overwrites an existing hook or hook manager).

## Before commit / PR
```bash
git status
git diff            # unstaged
git diff --staged   # staged
```
Check: every hunk is needed · no secret (`.env`, keys, tokens) · no debug output · no generated/build files · migrations and lockfiles intended.

Commit, push or open a PR only when the user asks.
