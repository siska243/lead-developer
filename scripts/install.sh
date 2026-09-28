#!/usr/bin/env bash
# Install the siska-lead-developer skill into a Skills directory of a
# Skills-compatible agent. Claude Code users: prefer the plugin (README),
# which also provides the /siska-lead-developer:<command> shortcuts.
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
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

if [ $UNINSTALL -eq 1 ]; then
  [ $LINK -eq 0 ] && [ $FORCE -eq 0 ] || sld_die "--uninstall cannot be combined with --link or --force"
  sld_info "target:  $TARGET"
  for name in "$MAIN_NAME" "$LEGACY_NAME"; do
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
  for name in "$MAIN_NAME" "$LEGACY_NAME"; do
    { [ -e "$TARGET/$name" ] || [ -L "$TARGET/$name" ]; } && sld_die "verification failed: $TARGET/$name still present"
  done
  sld_info "uninstalled. Backups ($TARGET/*.bak.*), if any, were kept. Restart your agent session."
  exit 0
fi

# 1. Detection
[ -f "$REPO_DIR/SKILL.md" ] || sld_die "SKILL.md not found in $REPO_DIR"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
conflicts=()
{ [ -e "$TARGET/$MAIN_NAME" ] || [ -L "$TARGET/$MAIN_NAME" ]; } && conflicts+=("$MAIN_NAME")

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

# 4. Verification
[ -f "$TARGET/$MAIN_NAME/SKILL.md" ] || sld_die "verification failed: $TARGET/$MAIN_NAME/SKILL.md missing"
[ -f "$TARGET/$MAIN_NAME/references/workflow.md" ] || sld_die "verification failed: references missing"
sld_info "installed and verified. Restart your agent session to load the skills."
