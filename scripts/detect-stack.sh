#!/usr/bin/env bash
# Detect the real technical stack of a project (read-only).
#
# Usage: bash detect-stack.sh [PROJECT_DIR]
#
# Prints one section per (sub)project found up to depth 3 (monorepos), then
# repository-wide infrastructure. Output is plain "key: value" lines so both
# humans and agents can read it. Only reports what files prove; never guesses.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

case "${1:-}" in -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

ROOT="$(sld_project_root "${1:-.}")"

join() { local IFS=' '; echo "${*:-none}"; }

detect_dir() {
  local rel="$1" d="$ROOT/$1"
  local langs=() frameworks=() pms=() tests=() mcp=()

  if [ -f "$d/composer.json" ]; then
    langs+=(php); pms+=(composer)
    sld_json_has_key "$d/composer.json" "laravel/framework" && frameworks+=(laravel)
    sld_json_has_key "$d/composer.json" "symfony/framework-bundle" && frameworks+=(symfony)
    sld_json_has_key "$d/composer.json" "pestphp/pest" && tests+=(pest)
    { sld_json_has_key "$d/composer.json" "phpunit/phpunit" || [ -f "$d/phpunit.xml" ] || [ -f "$d/phpunit.xml.dist" ]; } && tests+=(phpunit)
    sld_json_has_key "$d/composer.json" "laravel/mcp" && mcp+=(laravel/mcp)
    sld_json_has_key "$d/composer.json" "symfony/mcp-bundle" && mcp+=(symfony/mcp-bundle)
    sld_json_has_key "$d/composer.json" "mcp/sdk" && mcp+=(mcp/sdk)
  fi

  if [ -f "$d/package.json" ]; then
    local p="$d/package.json"
    langs+=(node); pms+=("$(sld_node_pm "$d")")
    { sld_json_has_key "$p" typescript || [ -f "$d/tsconfig.json" ]; } && langs+=(typescript)
    sld_json_has_key "$p" next && frameworks+=(next.js)
    sld_json_has_key "$p" expo && frameworks+=(expo)
    sld_json_has_key "$p" react-native && frameworks+=(react-native)
    sld_json_has_key "$p" react && frameworks+=(react)
    sld_json_has_key "$p" vue && frameworks+=(vue)
    sld_json_has_key "$p" express && frameworks+=(express)
    sld_json_has_key "$p" "@nestjs/core" && frameworks+=(nestjs)
    sld_json_has_key "$p" vite && frameworks+=(vite)
    sld_json_has_key "$p" tailwindcss && frameworks+=(tailwind)
    sld_json_has_key "$p" jest && tests+=(jest)
    sld_json_has_key "$p" vitest && tests+=(vitest)
    sld_json_has_key "$p" "@playwright/test" && tests+=(playwright)
    sld_json_has_key "$p" cypress && tests+=(cypress)
    sld_json_has_key "$p" "@modelcontextprotocol/sdk" && mcp+=(@modelcontextprotocol/sdk)
    # Motion libraries already installed: reuse them before adding any.
    local motion=() m
    for m in motion framer-motion react-native-reanimated react-native-gesture-handler lottie-react-native lottie-web "@rive-app/react-canvas" rive-react-native remotion gsap; do
      sld_json_has_key "$p" "$m" && motion+=("$m")
    done
    [ ${#motion[@]} -gt 0 ] && frameworks+=("motion:$(join ${motion[@]+"${motion[@]}"} | tr ' ' ',')")
  fi

  if [ -f "$d/pyproject.toml" ] || [ -f "$d/requirements.txt" ] || [ -f "$d/setup.py" ] || [ -f "$d/Pipfile" ]; then
    langs+=(python)
    if [ -f "$d/poetry.lock" ]; then pms+=(poetry)
    elif [ -f "$d/uv.lock" ]; then pms+=(uv)
    elif [ -f "$d/Pipfile" ]; then pms+=(pipenv)
    else pms+=(pip)
    fi
    sld_py_has_dep "$d" fastapi && frameworks+=(fastapi)
    sld_py_has_dep "$d" django && frameworks+=(django)
    sld_py_has_dep "$d" flask && frameworks+=(flask)
    { sld_py_has_dep "$d" pytest || [ -f "$d/pytest.ini" ] || [ -f "$d/conftest.py" ] || grep -q '\[tool.pytest' "$d/pyproject.toml" 2>/dev/null; } && tests+=(pytest)
    sld_py_has_dep "$d" mcp && mcp+=(mcp)
  fi

  echo "== $rel"
  echo "languages: $(join ${langs[@]+"${langs[@]}"})"
  echo "frameworks: $(join ${frameworks[@]+"${frameworks[@]}"})"
  echo "package_managers: $(join ${pms[@]+"${pms[@]}"})"
  echo "tests: $(join ${tests[@]+"${tests[@]}"})"
  echo "mcp_sdk: $(join ${mcp[@]+"${mcp[@]}"})"
}

detect_infra() {
  local infra=() ci=() f
  { [ -f "$ROOT/Dockerfile" ] || ls "$ROOT"/*/Dockerfile >/dev/null 2>&1; } && infra+=(docker)
  for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
    [ -f "$ROOT/$f" ] && { infra+=(docker-compose); break; }
  done
  [ -d "$ROOT/.github/workflows" ] && ci+=(github-actions)
  [ -f "$ROOT/.gitlab-ci.yml" ] && ci+=(gitlab-ci)
  [ -f "$ROOT/bitbucket-pipelines.yml" ] && ci+=(bitbucket)
  [ -f "$ROOT/Jenkinsfile" ] && ci+=(jenkins)
  [ -d "$ROOT/.circleci" ] && ci+=(circleci)
  [ -f "$ROOT/cdk.json" ] && infra+=(aws-cdk)
  { [ -f "$ROOT/serverless.yml" ] || [ -f "$ROOT/serverless.yaml" ]; } && infra+=(serverless)
  [ -f "$ROOT/template.yaml" ] && grep -q 'AWS::Serverless' "$ROOT/template.yaml" && infra+=(aws-sam)
  ls "$ROOT"/*.tf "$ROOT"/*/*.tf >/dev/null 2>&1 && infra+=(terraform)
  [ -f "$ROOT/eas.json" ] && infra+=(eas)
  [ -f "$ROOT/vercel.json" ] && infra+=(vercel)
  for f in .mcp.json mcp.json; do [ -f "$ROOT/$f" ] && infra+=("mcp-config:$f"); done

  echo "== repository"
  echo "infra: $(join ${infra[@]+"${infra[@]}"})"
  echo "ci: $(join ${ci[@]+"${ci[@]}"})"
  if sld_has_cmd git && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "git: yes (branch: $(sld_git_branch "$ROOT"), uncommitted: $(git -C "$ROOT" status --porcelain | wc -l | tr -d ' '))"
  else
    echo "git: no"
  fi
}

echo "project: $ROOT"
dirs="$(sld_project_dirs "$ROOT")"
if [ -z "$dirs" ]; then
  echo "== ."
  echo "languages: none detected (no composer.json, package.json, pyproject.toml, requirements.txt, setup.py, Pipfile up to depth 3)"
else
  while IFS= read -r rel; do detect_dir "$rel"; done <<<"$dirs"
fi
detect_infra
