#!/usr/bin/env bash
# Secret and data-leak scan of what is about to be committed.
#
# Usage: bash secret-scan.sh [PROJECT_DIR]
#
# Scans the added lines of the working diff vs HEAD (staged + unstaged) and the
# untracked files for hardcoded credentials: private keys, cloud/API tokens,
# JWTs, passwords in URLs, and password/secret/key/token assignments with a
# literal value. Also blocks sensitive files (keys, keystores, .htpasswd) and
# tracked .env files.
# A reviewed false positive is ignored when its line contains "siska:allow-secret".
# Read-only. Exit code: 0 clean, 1 possible leak found, 2 usage error or not a git repository.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

case "${1:-}" in -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ROOT="$(sld_project_root "${1:-.}")"
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || sld_die "not a git repository: $ROOT"
ROOT="$(git -C "$ROOT" rev-parse --show-toplevel)"
FOUND=0

# Without any commit yet, compare with the empty tree so staged files are scanned too.
base="HEAD"
git -C "$ROOT" rev-parse --verify -q HEAD >/dev/null || base="$(git -C "$ROOT" hash-object -t tree /dev/null)"
untracked="$(git -C "$ROOT" ls-files --others --exclude-standard)"

# Tracked .env files (templates like .env.example are allowed).
tracked_env="$(git -C "$ROOT" ls-files | grep -E '(^|/)\.env(\.[^/]*)?$' | grep -Ev '\.(example|sample|dist|template)$' || true)"
if [ -n "$tracked_env" ]; then
  sld_info "BLOCK: environment file(s) tracked by git: $(echo "$tracked_env" | tr '\n' ' ')"; FOUND=1
fi

# Sensitive files being added, whatever their content.
added_files="$(git -C "$ROOT" diff "$base" --name-only --diff-filter=A 2>/dev/null; printf '%s\n' "$untracked")"
sensitive="$(printf '%s\n' "$added_files" | grep -Ei '(\.(pem|key|p12|pfx|jks|keystore|ppk|asc)|(^|/)id_(rsa|dsa|ecdsa|ed25519)|(^|/)\.htpasswd|(^|/)service-account[^/]*\.json)$' || true)"
if [ -n "$sensitive" ]; then
  sld_info "BLOCK: sensitive file(s) added (keys, keystores, credentials): $(echo "$sensitive" | tr '\n' ' ')"; FOUND=1
fi

# Added lines as "file:content": diff hunks, then untracked text files (-I skips binaries).
added="$(git -C "$ROOT" diff "$base" --no-color -U0 2>/dev/null |
  awk '/^\+\+\+ /{f=substr($0,7); next} /^\+/{print f ":" substr($0,2)}')"
while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$ROOT/$f" ] && added+=$'\n'"$(grep -HI '' "$ROOT/$f" 2>/dev/null | sed "s|^$ROOT/||")"
done <<<"$untracked"
added="$(printf '%s\n' "$added" | grep -v 'siska:allow-secret' || true)"

# Provider formats: unambiguous, reported as is.
token_re='-----BEGIN [A-Z ]*PRIVATE KEY-----|(AKIA|ASIA)[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|hooks\.slack\.com/services/[A-Za-z0-9/]{20,}|(sk|rk)_(live|test)_[0-9A-Za-z]{16,}|AIza[0-9A-Za-z_-]{35}|sk-(ant-|proj-)?[A-Za-z0-9_-]{32,}|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|_auth(Token)?[[:space:]]*=[[:space:]]*[^[:space:]$]{8,}'
# Password in a connection URL (scheme://user:<password>@host), not a ${VAR} or <placeholder>.
url_re='[a-z][a-z0-9+.-]*://[^/[:space:]:@]+:[^/[:space:]@$<{]{3,}@'
# Sensitive name assigned a literal: quoted in code/JSON (not a "$VAR" reference), or unquoted UPPER_CASE in YAML/ini/compose.
q="[\"'\`]"
assign_re="(password|passwd|pwd|secret|api[_-]?key|access[_-]?key|private[_-]?key|token|credentials?)[a-z0-9_-]*$q?[[:space:]]*(:|=|=>)[[:space:]]*$q[^\"'\`[:space:]\$][^\"'\`[:space:]]{7,}$q"
upper_re='(PASSWORD|PASSWD|SECRET|API_KEY|ACCESS_KEY|PRIVATE_KEY|TOKEN)[A-Z0-9_]*[[:space:]]*[:=][[:space:]]*[^[:space:]"'"'"'$<{#().;,]{8,}([[:space:]]|$)'
# Obvious placeholders, only for the name-based rules.
placeholder_re="$q(password|secret|changeme|placeholder|dummy|example|x{4,}|\*{4,})[0-9]*$q|your[_-]|xxxx|<[a-z_-]+>|changeme|example"

leaks="$(
  printf '%s\n' "$added" | grep -E -- "$token_re|$url_re"
  printf '%s\n' "$added" | grep -Ei -- "$assign_re" | grep -Eiv -- "$placeholder_re"
  printf '%s\n' "$added" | grep -E -- "$upper_re" | grep -Eiv -- "$placeholder_re"
)"
leaks="$(printf '%s\n' "$leaks" | grep -v '^$' | sort -u | cut -c1-160 || true)"
if [ -n "$leaks" ]; then
  sld_info "BLOCK: possible secret(s) in changes (move them to env vars / a secret manager; reviewed false positive: add a 'siska:allow-secret' comment on the line):"
  printf '%s\n' "$leaks"
  FOUND=1
fi

[ $FOUND -eq 0 ] && sld_info "OK:    no secret, key or sensitive file in changes"
exit $FOUND
