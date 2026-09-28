# Dependencies

## Audit (detect the stack first – `bash scripts/security-audit.sh <project>` does it)
| Stack | Commands |
|-------|----------|
| Composer | `composer audit` · `composer outdated --direct` · `composer update --dry-run` |
| npm | `npm audit` · `npm outdated` |
| pnpm | `pnpm audit` · `pnpm outdated` |
| Yarn | `yarn npm audit` (Berry) or `yarn audit` (v1) · `yarn outdated` |
| Bun | `bun audit` (recent versions) · `bun outdated` |
| Python | `pip-audit` (or `pip-audit -r requirements.txt`) · `pip list --outdated` |
| Expo | `npx expo install --check` (SDK-compatible versions) |

Use the package manager matching the lockfile. Never mix them.

## Updating – never massively without reason
1. Identify the reason (vulnerability, bug, required feature).
2. Check the vulnerability (advisory, affected range, exploitable in this project?).
3. Find the smallest fixing version (patch > minor > major).
4. Read the changelog / breaking changes.
5. Check dependents and peer constraints.
6. Update only that package (`composer update vendor/pkg`, `npm install pkg@x.y.z`).
7. Run the test suite and check regressions.
8. Commit lockfile together with manifest.

## Adding a dependency
Only if the project, the framework, the standard library and already-installed packages cannot do it reasonably. Check: maintenance activity, license, size, security history, transitive deps.
