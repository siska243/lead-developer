#!/usr/bin/env bash
# Install the siska-lead-developer skill and its commands (siska-audit-route,
# siska-check-code, …) into the skills directory of a Skills-compatible agent
# (Codex, GitHub Copilot, OpenCode… read ~/.agents/skills). Commands are
# generated from skills/ with absolute paths, so they work in any agent.
# Claude Code users: prefer the plugin (README).
#
# Usage: bash install.sh [--target DIR] [--link] [--force] [--dry-run]
#        bash install.sh --uninstall [--target DIR] [--dry-run]
#
#   --target DIR  skills directory (default: $HOME/.agents/skills).
#                 See compat/ for the directory each agent reads.
#   --link        symlink to this repository instead of copying (development).
#   --force       replace an existing install; the old one is moved to
#                 <name>.bak.<timestamp> first, never deleted.
#   --dry-run     print the plan, change nothing.
#   --uninstall   remove both skills from DIR. Only removes a symlink or a
#                 directory whose SKILL.md declares the expected skill name;
#                 anything else is left untouched. Backups (*.bak.*) are kept.
#
# Never overwrites silently: an existing install stops the script unless --force.
# Claude Code: the plugin is the supported install (README). Installing into a
# Claude Code skills directory while the plugin is installed is refused (duplicate).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET="${HOME}/.agents/skills" LINK=0 FORCE=0 DRY=0 UNINSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --target) [ $# -ge 2 ] || sld_die "--target needs a directory"; TARGET="$2"; shift ;;
    --link) LINK=1 ;;
    --force) FORCE=1 ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) sld_die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

# name -> source directory inside this repository.
MAIN_NAME="siska-lead-developer"
# Entry skill installed by version 1.0.0; still removed by --uninstall.
LEGACY_NAME="siska-lead-mcp"
# What a copy install ships (development files like tests/ stay in the repo).
MAIN_CONTENT="SKILL.md README.md LICENSE CHANGELOG.md references scripts templates compat"
# Portable commands generated from skills/<cmd>/SKILL.md as siska-<cmd>.
COMMANDS=()
for d in "$REPO_DIR"/skills/*/; do [ -f "$d/SKILL.md" ] && COMMANDS+=("siska-$(basename "$d")"); done
ALL_NAMES=("$MAIN_NAME" ${COMMANDS[@]+"${COMMANDS[@]}"})

# generate_command SRC_SKILL_MD DEST_DIR MAIN_PATH: portable copy of a command skill.
# Replaces agent-specific placeholders; keeps only standard frontmatter fields.
# shellcheck disable=SC2016 # the ${…} and $ARGUMENTS below are literal text to replace
generate_command() {
  mkdir -p "$2"
  sed -e '1,/^---$/!b' -e 's/^name: /name: siska-/' -e '/^disable-model-invocation:/d' -e '/^argument-hint:/d' "$1" |
    sed -e 's|\${CLAUDE_SKILL_DIR}/\.\./\.\.|'"$3"'|g' \
        -e 's|^Arguments: `\$ARGUMENTS`$|Arguments: what the user wrote after the skill name.|' \
        -e 's|/siska-lead-developer:siska-lead-developer|siska-lead-developer|g' \
        -e 's|/siska-lead-developer:|siska-|g' >"$2/SKILL.md"
}

if [ $UNINSTALL -eq 1 ]; then
  [ $LINK -eq 0 ] && [ $FORCE -eq 0 ] || sld_die "--uninstall cannot be combined with --link or --force"
  sld_info "target:  $TARGET"
  for name in "${ALL_NAMES[@]}" "$LEGACY_NAME"; do
    path="$TARGET/$name"
    if [ -L "$path" ]; then
      sld_info "remove:  $path (symlink -> $(readlink "$path")); the linked repository is not touched"
      [ $DRY -eq 1 ] || rm "$path"
    elif [ -d "$path" ]; then
      # Only delete what this installer created: a directory declaring this skill name.
      grep -q "^name: $name\$" "$path/SKILL.md" 2>/dev/null \
        || sld_die "$path does not look like the $name skill – left untouched, remove it manually"
      sld_info "remove:  $path (copy)"
      [ $DRY -eq 1 ] || rm -rf "$path"
    else
      sld_info "skip:    $path (not installed)"
    fi
  done
  if [ $DRY -eq 1 ]; then sld_info "dry run: nothing changed"; exit 0; fi
  for name in "${ALL_NAMES[@]}" "$LEGACY_NAME"; do
    { [ -e "$TARGET/$name" ] || [ -L "$TARGET/$name" ]; } && sld_die "verification failed: $TARGET/$name still present"
  done
  sld_info "uninstalled. Backups ($TARGET/*.bak.*), if any, were kept. Restart your agent session."
  exit 0
fi

# 1. Detection
[ -f "$REPO_DIR/SKILL.md" ] || sld_die "SKILL.md not found in $REPO_DIR"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
conflicts=()
for name in "${ALL_NAMES[@]}"; do
  { [ -e "$TARGET/$name" ] || [ -L "$TARGET/$name" ]; } && conflicts+=("$name")
done

# Claude Code reads .claude/skills, not ~/.agents/skills, and has its own plugin install.
CLAUDE_HOME="${SLD_CLAUDE_HOME:-$HOME/.claude}"
case "$TARGET" in
  */.claude/skills|*/.claude/skills/)
    if grep -q '"siska-lead-developer@' "$CLAUDE_HOME/plugins/installed_plugins.json" 2>/dev/null; then
      sld_die "the siska-lead-developer plugin is already installed in Claude Code; this copy would duplicate it. Keep the plugin (update: /plugin), or uninstall it first."
    fi
    sld_warn "Claude Code: the plugin is recommended (/plugin marketplace add siska243/lead-developer, then /plugin install siska-lead-developer@siska); this copy has no /siska-lead-developer:<command> shortcuts." ;;
  *)
    sld_has_cmd claude && sld_warn "Claude Code does not read $TARGET. For Claude Code, use the plugin (README) instead of this script." ;;
esac

# 2. Plan
mode="copy"; [ $LINK -eq 1 ] && mode="symlink"
sld_info "source:  $REPO_DIR"
sld_info "target:  $TARGET"
sld_info "mode:    $mode"
for name in ${conflicts[@]+"${conflicts[@]}"}; do
  if [ $FORCE -eq 1 ]; then
    sld_info "backup:  $TARGET/$name -> $TARGET/$name.bak.$TIMESTAMP"
  else
    sld_die "$TARGET/$name already exists. Re-run with --force to replace it (a backup is kept)."
  fi
done
sld_info "install: $TARGET/$MAIN_NAME"
sld_info "install: ${#COMMANDS[@]} commands (${COMMANDS[*]})"
[ $DRY -eq 1 ] && { sld_info "dry run: nothing changed"; exit 0; }

# 3. Modification
mkdir -p "$TARGET"
for name in ${conflicts[@]+"${conflicts[@]}"}; do mv "$TARGET/$name" "$TARGET/$name.bak.$TIMESTAMP"; done

if [ $LINK -eq 1 ]; then
  ln -s "$REPO_DIR" "$TARGET/$MAIN_NAME"
else
  mkdir "$TARGET/$MAIN_NAME"
  for item in $MAIN_CONTENT; do
    [ -e "$REPO_DIR/$item" ] && cp -R "$REPO_DIR/$item" "$TARGET/$MAIN_NAME/"
  done
fi

TARGET_ABS="$(cd "$TARGET" && pwd)"
for cmd in ${COMMANDS[@]+"${COMMANDS[@]}"}; do
  generate_command "$REPO_DIR/skills/${cmd#siska-}/SKILL.md" "$TARGET/$cmd" "$TARGET_ABS/$MAIN_NAME"
done

# 4. Verification
[ -f "$TARGET/$MAIN_NAME/SKILL.md" ] || sld_die "verification failed: $TARGET/$MAIN_NAME/SKILL.md missing"
[ -f "$TARGET/$MAIN_NAME/references/workflow.md" ] || sld_die "verification failed: references missing"
for cmd in ${COMMANDS[@]+"${COMMANDS[@]}"}; do
  grep -q "^name: $cmd\$" "$TARGET/$cmd/SKILL.md" 2>/dev/null || sld_die "verification failed: $TARGET/$cmd/SKILL.md"
  # shellcheck disable=SC2016 # literal placeholders searched for
  ! grep -q 'CLAUDE_SKILL_DIR\|\$ARGUMENTS' "$TARGET/$cmd/SKILL.md" || sld_die "verification failed: agent-specific placeholder left in $cmd"
done
sld_info "installed and verified. Restart your agent session to load the skills."
