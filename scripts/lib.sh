#!/usr/bin/env bash
# Shared helpers for siska-lead-developer scripts. Source it, do not execute it.
# Read-only: nothing here writes to the analyzed project.

# Manifests that mark a (sub)project root.
SLD_MANIFESTS="composer.json package.json pyproject.toml requirements.txt setup.py Pipfile"

# Directories never worth scanning (dependencies, builds, VCS, virtualenvs).
SLD_PRUNE_DIRS="node_modules vendor .git dist build .next .expo .venv venv __pycache__ .cache coverage"

sld_info() { printf '%s\n' "$*"; }
sld_warn() { printf 'WARN: %s\n' "$*" >&2; }
sld_die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

sld_has_cmd() { command -v "$1" >/dev/null 2>&1; }

# Resolve and validate the project root given as first argument (default: cwd).
sld_project_root() {
  local root="${1:-.}"
  [ -d "$root" ] || sld_die "not a directory: $root"
  (cd "$root" && pwd)
}

# Print every directory (relative to ROOT, "." for root) containing a manifest,
# up to depth 3, so monorepos (backend/, frontend/, apps/*) are covered.
sld_project_dirs() {
  local root="$1" prune_expr=() name first=1
  for name in $SLD_PRUNE_DIRS; do
    if [ $first -eq 1 ]; then first=0; else prune_expr+=(-o); fi
    prune_expr+=(-name "$name")
  done
  local match_expr=() first=1
  for name in $SLD_MANIFESTS; do
    if [ $first -eq 1 ]; then first=0; else match_expr+=(-o); fi
    match_expr+=(-name "$name")
  done
  (cd "$root" && find . -maxdepth 3 \( -type d \( "${prune_expr[@]}" \) -prune \) -o \
    \( -type f \( "${match_expr[@]}" \) -print \)) |
    sed -e 's|/[^/]*$||' -e 's|^\./||' | sort -u
}

# sld_json_has_key FILE KEY -> true if "KEY": appears (dependency or script name).
sld_json_has_key() {
  [ -f "$1" ] && grep -Eq "\"$2\"[[:space:]]*:" "$1"
}

# sld_py_has_dep DIR NAME -> true if a Python manifest in DIR declares NAME.
sld_py_has_dep() {
  local dir="$1" name="$2" f
  for f in "$dir"/pyproject.toml "$dir"/requirements*.txt "$dir"/setup.py "$dir"/Pipfile; do
    [ -f "$f" ] || continue
    grep -Eiq "(^|[\"' ])$name([<>=!~;,\" '[]|\$)" "$f" && return 0
  done
  return 1
}

# Node package manager, decided by lockfile (never mix managers).
sld_node_pm() {
  local dir="$1"
  if [ -f "$dir/pnpm-lock.yaml" ]; then echo pnpm
  elif [ -f "$dir/yarn.lock" ]; then echo yarn
  elif [ -f "$dir/bun.lock" ] || [ -f "$dir/bun.lockb" ]; then echo bun
  elif [ -f "$dir/package-lock.json" ]; then echo npm
  else echo "npm (no lockfile)"
  fi
}

# Current branch, also on a repository without commits (unborn branch).
sld_git_branch() {
  git -C "$1" symbolic-ref --short HEAD 2>/dev/null || git -C "$1" rev-parse --short HEAD 2>/dev/null || echo unknown
}
