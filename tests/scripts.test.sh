#!/usr/bin/env bash
# Self-check for scripts/: builds throwaway fixture projects and asserts outputs.
# Usage: bash tests/scripts.test.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

assert_contains() { # name haystack needle
  if printf '%s' "$2" | grep -qF -- "$3"; then echo "ok   $1"; else echo "FAIL $1: missing '$3'"; FAILS=$((FAILS + 1)); fi
}
check() { # name command... -> pass when the command succeeds
  local name="$1"; shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; FAILS=$((FAILS + 1)); fi
}
assert_status() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: exit $3, expected $2"; FAILS=$((FAILS + 1)); fi
}

# --- detect-stack: monorepo fixture ---
P="$TMP/app"
mkdir -p "$P/backend" "$P/mobile" "$P/api/node_modules/dep" "$P/.github/workflows"
echo '{"require":{"laravel/framework":"^11.0","laravel/mcp":"^1.0"},"require-dev":{"pestphp/pest":"^3"}}' >"$P/backend/composer.json"
echo '{"dependencies":{"expo":"~52","react":"18","react-native":"0.76","react-native-reanimated":"3"},"devDependencies":{"jest":"29"}}' >"$P/mobile/package.json"
touch "$P/mobile/yarn.lock" "$P/Dockerfile" "$P/.github/workflows/ci.yml"
printf 'fastapi>=0.110\npytest==8\n' >"$P/api/requirements.txt"
echo '{"dependencies":{"next":"1"}}' >"$P/api/node_modules/dep/package.json"

out="$(bash "$REPO/scripts/detect-stack.sh" "$P")"
assert_contains "laravel detected" "$out" "frameworks: laravel"
assert_contains "laravel/mcp detected" "$out" "mcp_sdk: laravel/mcp"
assert_contains "pest detected" "$out" "tests: pest"
assert_contains "expo + RN + reanimated detected" "$out" "frameworks: expo react-native react motion:react-native-reanimated"
assert_contains "yarn from lockfile" "$out" "package_managers: yarn"
assert_contains "fastapi detected" "$out" "frameworks: fastapi"
assert_contains "pytest detected" "$out" "tests: pytest"
assert_contains "docker detected" "$out" "infra: docker"
assert_contains "github actions detected" "$out" "ci: github-actions"
not_contains() { ! printf '%s' "$1" | grep -qF -- "$2"; }
check "node_modules ignored" not_contains "$out" "next.js"

out="$(bash "$REPO/scripts/detect-stack.sh" "$TMP/does-not-exist" 2>&1)" && s=0 || s=$?
assert_status "detect-stack rejects missing dir" 2 "$s"

# --- security-audit: no tool can prove anything -> must not claim success ---
E="$TMP/empty-node"; mkdir -p "$E"; echo '{"name":"x"}' >"$E/package.json"
out="$(bash "$REPO/scripts/security-audit.sh" "$E" 2>&1)" && s=0 || s=$?
assert_status "audit without lockfile is not a success" 1 "$s"
assert_contains "audit reports missing lockfile" "$out" "without lockfile"

# --- check-project: secret and tracked .env are blocking ---
if command -v git >/dev/null 2>&1; then
  G="$TMP/repo"; mkdir -p "$G"
  git -C "$G" init -q -b feature/x
  echo '{"scripts":{"test":"node -e \"process.exit(0)\""}}' >"$G/package.json"
  touch "$G/package-lock.json"
  git -C "$G" add . && git -C "$G" -c user.email=t@t -c user.name=t commit -qm init
  out="$(bash "$REPO/scripts/check-project.sh" "$G" --run-tests 2>&1)" && s=0 || s=$?
  assert_status "clean repo passes" 0 "$s"
  assert_contains "test command found" "$out" "found: [.] npm test"

  echo 'const key = "AKIAABCDEFGHIJKLMNOP";' >"$G/leak.js"
  echo 'DB_PASSWORD=x' >"$G/.env" && git -C "$G" add -f .env
  out="$(bash "$REPO/scripts/check-project.sh" "$G" 2>&1)" && s=0 || s=$?
  assert_status "secret blocks delivery" 1 "$s"
  assert_contains "secret reported" "$out" "possible secret"
  assert_contains "tracked .env reported" "$out" "environment file(s) tracked"
fi

# --- check-project: repository without commits, secret only staged ---
if command -v git >/dev/null 2>&1; then
  U="$TMP/unborn"; mkdir -p "$U"
  git -C "$U" init -q -b feature/y
  echo 'aws = "AKIAABCDEFGHIJKLMNOP"' >"$U/conf.py" && git -C "$U" add conf.py
  out="$(bash "$REPO/scripts/check-project.sh" "$U" 2>&1)" && s=0 || s=$?
  assert_status "staged secret blocks before first commit" 1 "$s"
  assert_contains "unborn branch name" "$out" "branch 'feature/y'"
fi

# --- install: dry run, real install, refusal to overwrite, forced backup ---
T="$TMP/skills"
bash "$REPO/scripts/install.sh" --target "$T" --dry-run >/dev/null
check "dry run changes nothing" test ! -e "$T/siska-lead-developer"
bash "$REPO/scripts/install.sh" --target "$T" >/dev/null
check "install copies main skill" test -f "$T/siska-lead-developer/references/mcp.md"
check "dev files not shipped" test ! -e "$T/siska-lead-developer/tests"
bash "$REPO/scripts/install.sh" --target "$T" >/dev/null 2>&1 && s=0 || s=$?
assert_status "existing install is not overwritten" 2 "$s"
bash "$REPO/scripts/install.sh" --target "$T" --force >/dev/null
backups=("$T"/siska-lead-developer.bak.*)
check "force keeps a backup" test -d "${backups[0]}"

bash "$REPO/scripts/install.sh" --uninstall --target "$T" --dry-run >/dev/null
check "uninstall dry run changes nothing" test -d "$T/siska-lead-developer"
mkdir -p "$TMP/foreign/siska-lead-mcp" && echo "name: other" >"$TMP/foreign/siska-lead-mcp/SKILL.md"
bash "$REPO/scripts/install.sh" --uninstall --target "$TMP/foreign" >/dev/null 2>&1 && s=0 || s=$?
assert_status "uninstall refuses a foreign directory" 2 "$s"
check "foreign directory kept" test -f "$TMP/foreign/siska-lead-mcp/SKILL.md"
bash "$REPO/scripts/install.sh" --uninstall --target "$T" >/dev/null
check "uninstall removes copy" test ! -e "$T/siska-lead-developer"
check "uninstall keeps backups" test -d "${backups[0]}"
L="$TMP/linked"
bash "$REPO/scripts/install.sh" --target "$L" --link >/dev/null
bash "$REPO/scripts/install.sh" --uninstall --target "$L" >/dev/null
check "uninstall removes symlinks" test ! -L "$L/siska-lead-developer"
check "uninstall keeps the linked repository" test -f "$REPO/SKILL.md"

# --- install: Claude Code target with the plugin already installed is refused ---
C="$TMP/home/.claude"; mkdir -p "$C/plugins"
echo '{"plugins":{"siska-lead-developer@siska":[{}]}}' >"$C/plugins/installed_plugins.json"
out="$(SLD_CLAUDE_HOME="$C" bash "$REPO/scripts/install.sh" --target "$C/skills" 2>&1)" && s=0 || s=$?
assert_status "no duplicate of the Claude Code plugin" 2 "$s"
assert_contains "duplicate reason explained" "$out" "plugin is already installed"
check "nothing installed next to the plugin" test ! -e "$C/skills/siska-lead-developer"
rm "$C/plugins/installed_plugins.json"
out="$(SLD_CLAUDE_HOME="$C" bash "$REPO/scripts/install.sh" --target "$C/skills" --dry-run 2>&1)"
assert_contains "plugin recommended for Claude Code" "$out" "the plugin is recommended"

echo "---"
if [ $FAILS -ne 0 ]; then echo "$FAILS check(s) failed"; exit 1; fi
echo "all script checks passed"
