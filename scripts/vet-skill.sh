#!/usr/bin/env bash
# Static security review of a skill, plugin or MCP server BEFORE installing it.
#
# Usage: bash vet-skill.sh <DIR>
#
# Never executes anything from DIR. Reports what the package can do: scripts,
# hooks (run automatically), bundled MCP servers, allowed-tools, network calls,
# secret access, destructive or obfuscated commands, hidden instructions.
# Exit code: 0 no HIGH finding, 1 HIGH finding (refuse unless justified), 2 usage.
# A clean result is not a guarantee: read SKILL.md and every flagged file.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

case "${1:-}" in ''|-h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; [ -n "${1:-}" ]; exit $? ;; esac
[ -d "$1" ] || sld_die "not a directory: $1 (clone or download it first, without running it)"
DIR="$(cd "$1" && pwd)"
HIGH=0 MEDIUM=0

report() { # LEVEL message
  case "$1" in HIGH) HIGH=$((HIGH + 1)) ;; MEDIUM) MEDIUM=$((MEDIUM + 1)) ;; esac
  printf '%-6s %s\n' "$1" "$2"
}

# scan LEVEL LABEL REGEX: report each matching line (file:line), capped.
scan() {
  local hits
  hits="$(grep -rInE --exclude-dir=.git --exclude-dir=node_modules -- "$3" "$DIR" 2>/dev/null | sed "s|^$DIR/||" | cut -c1-160 | head -n 10)"
  [ -n "$hits" ] || return 0
  report "$1" "$2:"
  printf '%s\n' "$hits" | sed 's/^/         /'
}

echo "package: $DIR"
skills="$(find "$DIR" -name SKILL.md -not -path '*/node_modules/*' | wc -l | tr -d ' ')"
[ "$skills" -gt 0 ] || report HIGH "no SKILL.md: not a skill package"
echo "skills:  $skills"

# Provenance.
license="$(find "$DIR" -maxdepth 1 -type f -iname 'LICEN[CS]E*' | head -n 1)"
if [ -n "$license" ]; then echo "license: $(head -n 1 "$license")"; else report MEDIUM "no LICENSE file"; fi
if git -C "$DIR" rev-parse >/dev/null 2>&1; then
  echo "source:  $(git -C "$DIR" remote get-url origin 2>/dev/null || echo unknown) @ $(git -C "$DIR" log -1 --format='%h %cs' 2>/dev/null)"
fi

# What runs, and when.
files="$(find "$DIR" -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.py' -o -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.rb' -o -name '*.pl' -o -name '*.ps1' \) -not -path '*/node_modules/*' -not -path '*/.git/*' | sed "s|^$DIR/||")"
[ -n "$files" ] && { report INFO "executable code ($(printf '%s\n' "$files" | wc -l | tr -d ' ') files):"; printf '%s\n' "$files" | head -n 15 | sed 's/^/         /'; }
bins="$(find "$DIR" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -exec grep -IL . {} + 2>/dev/null | grep -Eiv '\.(png|jpe?g|gif|svg|webp|ico|woff2?|ttf|otf|pdf|mp4|webm|lottie|riv)$' | sed "s|^$DIR/||" | head -n 10)"
[ -n "$bins" ] && { report MEDIUM "binary files (cannot be reviewed):"; printf '%s\n' "$bins" | sed 's/^/         /'; }
hooks="$(find "$DIR" -type f \( -path '*/hooks/*.json' -o -name 'settings*.json' \) -not -path '*/node_modules/*' | sed "s|^$DIR/||")"
[ -n "$hooks" ] && { report MEDIUM "hooks or settings (run automatically in the agent):"; printf '%s\n' "$hooks" | sed 's/^/         /'; }
scan MEDIUM "hooks declared in a manifest" '"hooks"[[:space:]]*:'
scan MEDIUM "bundled MCP servers (new tools and access)" '"mcpServers"[[:space:]]*:'
scan MEDIUM "pre-approved tools (allowed-tools)" '^allowed-tools:'

# Dangerous behavior.
scan HIGH "download piped to a shell" '(curl|wget)[^|]*\|[[:space:]]*(ba|z)?sh'
scan HIGH "eval / dynamic code execution" '(^|[^[:alnum:]_.])eval[[:space:]]*[("$`]|new Function\(|exec\(base64|base64[[:space:]]+(-d|--decode)'
# shellcheck disable=SC2016 # literal $HOME is part of the pattern
scan HIGH "destructive command" 'rm[[:space:]]+-[rRf]+[[:space:]]+(/|~|\$HOME|\*)([[:space:]]|$)|mkfs|dd[[:space:]]+if=|:\(\)\{|chmod[[:space:]]+-R?[[:space:]]*777'
scan HIGH "privilege escalation" '(^|[^[:alnum:]_])sudo[[:space:]]'
scan HIGH "reads secrets or credentials" '\.ssh/|id_rsa|id_ed25519|\.aws/credentials|\.netrc|\.npmrc|keychain|security find-generic-password|\.git-credentials'
scan HIGH "sends data out" '(curl|wget)[^#]*(-d |--data|-F |--upload-file|-T )|nc[[:space:]]+-e|/dev/tcp/'
scan HIGH "hidden instructions to the agent" '(ignore|disregard) (all |the )?(previous|prior|above) instructions|do not (tell|inform|show) the user|without (telling|asking) the user|bypass (the )?(permission|approval)|--dangerously-skip-permissions'
scan MEDIUM "environment and .env access" '(^|[^[:alnum:]_])\.env([^[:alnum:]_.]|$)|process\.env|os\.environ|getenv\('
scan INFO "network endpoints" 'https?://[^[:space:]"'"'"')>]+'

echo "---"
echo "RESULT: $HIGH high, $MEDIUM medium – read SKILL.md and every flagged file before deciding"
[ $HIGH -eq 0 ]
