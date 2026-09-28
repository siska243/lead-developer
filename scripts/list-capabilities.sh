#!/usr/bin/env bash
# List the skills and MCP servers installed for AI coding agents (read-only).
#
# Usage: bash list-capabilities.sh [PROJECT_DIR]
#
# Skills: SKILL.md folders in the known user and project skill directories and
# in installed agent plugins. MCP: servers declared in known MCP config files.
# Output: "skill: <name> | <description> | <path>" and "mcp: <name> | <config file>".
# Set SLD_HOME to scan another home directory (tests).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

case "${1:-}" in -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ROOT="$(sld_project_root "${1:-.}")"
H="${SLD_HOME:-$HOME}"

# Known locations. Add an agent here, not in the logic below.
SKILL_DIRS=("$H/.agents/skills" "$H/.claude/skills" "$H/.codex/skills" "$ROOT/.agents/skills" "$ROOT/.claude/skills")
PLUGIN_REGISTRIES=("$H/.claude/plugins/installed_plugins.json")
MCP_FILES=("$ROOT/.mcp.json" "$ROOT/mcp.json" "$ROOT/.cursor/mcp.json" "$ROOT/.vscode/mcp.json" "$H/.claude.json" "$H/.cursor/mcp.json" "$H/.codeium/windsurf/mcp_config.json")

# json_eval FILE PYTHON_EXPR: print lines computed from the parsed JSON "d".
json_eval() {
  if sld_has_cmd python3; then
    python3 -c "import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
$2" "$1" 2>/dev/null
  else
    sld_warn "python3 not found: cannot read $1"
  fi
}

frontmatter() { # FILE KEY -> value of "KEY:" in the YAML frontmatter
  sed -n '1,/^---$/{/^'"$2"':/{s/^'"$2"':[[:space:]]*//;p;q;}}' "$1" | cut -c1-120
}

print_skill() { # SKILL.md path
  local f="$1"
  echo "skill: $(frontmatter "$f" name) | $(frontmatter "$f" description) | $(dirname "$f")"
}

# Plugin install paths (each may hold skills/<name>/SKILL.md or a root SKILL.md).
PLUGIN_DIRS=()
for reg in "${PLUGIN_REGISTRIES[@]}"; do
  [ -f "$reg" ] || continue
  while IFS= read -r p; do [ -n "$p" ] && PLUGIN_DIRS+=("$p"); done < <(json_eval "$reg" '
for entries in (d.get("plugins") or {}).values():
    for e in entries:
        if e.get("installPath"): print(e["installPath"])')
done

found=0
for dir in "${SKILL_DIRS[@]}" ${PLUGIN_DIRS[@]+"${PLUGIN_DIRS[@]}"}; do
  [ -d "$dir" ] || continue
  while IFS= read -r f; do print_skill "$f"; found=$((found + 1)); done < <(
    find -L "$dir" -maxdepth 3 -name SKILL.md -not -path '*/node_modules/*' 2>/dev/null | sort)
done
[ $found -gt 0 ] || echo "skill: none found"

found=0
for f in "${MCP_FILES[@]}" ${PLUGIN_DIRS[@]+"${PLUGIN_DIRS[@]/%//.mcp.json}"}; do
  [ -f "$f" ] || continue
  while IFS= read -r name; do
    [ -n "$name" ] && { echo "mcp: $name | $f"; found=$((found + 1)); }
  done < <(json_eval "$f" '
servers = d.get("mcpServers") or d.get("servers") or {}
for name in servers: print(name)
for proj in (d.get("projects") or {}).values():
    for name in (proj.get("mcpServers") or {}): print(name + " (project scope)")')
done
[ $found -gt 0 ] || echo "mcp: none found"
