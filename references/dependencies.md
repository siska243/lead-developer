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

## Maintenance status (direct dependencies)
A package is **at risk** when: deprecated / abandoned · repository archived · no release for more than 24 months · open advisory without fix. Propose a maintained replacement; never swap silently.

| Stack | Command (run in the project directory) |
|-------|---------|
| Composer | `composer show --locked --direct --latest --format=json` (fields `abandoned`, `release-date`, `latest-status`) + `composer audit --locked --abandoned=report` |
| Node (any lockfile) | see snippet below – uses the project's registry config |
| Python | PyPI JSON per package: `https://pypi.org/pypi/<pkg>/json` (latest version upload date, `Development Status :: 7 - Inactive`) |

Node, one line per direct dependency (`name  latest  last-release  DEPRECATED  repo`):
```bash
node -e 'const p=require("./package.json");for(const n of Object.keys({...p.dependencies,...p.devDependencies}))console.log(n)' |
while read -r pkg; do npm view "$pkg" --json 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s),v=j["dist-tags"].latest;console.log([j.name,v,(j.time||{})[v]?.slice(0,10),j.deprecated?"DEPRECATED":"-",(j.repository&&j.repository.url)||"-"].join("\t"))})'; done
```
Archived repository: check the repository URL (GitHub shows "archived"; `gh repo view <owner/repo> --json isArchived` if `gh` is available).

## Unused dependencies
Detect with a dedicated tool – already in the project first, otherwise ask before downloading one:

| Stack | Tool |
|-------|------|
| Node | `npx knip --dependencies` (maintained; prefer over depcheck) |
| Composer | `composer-unused` (`icanhazstring/composer-unused`) |
| Python | `deptry .` |

Tools report **candidates**, not facts. Before proposing removal, verify each one is not used by: config files (babel, eslint, postcss, tailwind, vite, jest, tsconfig…), `package.json` / `composer.json` scripts, CI and Dockerfiles, CLI binaries, `@types/*` of a used library, peer dependencies, plugins loaded by name, dynamic imports, framework auto-discovery (Laravel providers/facades/commands, Symfony bundles, Expo config plugins).

## Removing
Only after the user approves the list. One logical group at a time, with the project's manager (`composer remove`, `npm uninstall`, `pnpm remove`, `yarn remove`, `bun remove`, `poetry remove`, `uv remove`, or `pip uninstall` + remove from `requirements*.txt`/`pyproject.toml`). Then: lockfile committed, tests + build run (Expo: `npx expo install --check`), app started when possible.

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
