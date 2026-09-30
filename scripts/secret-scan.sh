#!/usr/bin/env bash
# Secret and data-leak scan of what is about to be committed, of a commit range, or of the whole history.
#
# Usage: bash secret-scan.sh [PROJECT_DIR]                  working changes (staged, unstaged, untracked)
#        bash secret-scan.sh [PROJECT_DIR] --range A..B     commits of a range (CI: base..head of a PR)
#        bash secret-scan.sh [PROJECT_DIR] --history        every commit of every branch
#
# Looks for hardcoded credentials in added lines: private keys, cloud/API tokens,
# JWTs, passwords in URLs, and password/secret/key/token assignments with a
# literal value. Also blocks sensitive files (keys, keystores, .htpasswd) and
# .env files (tracked now, or ever added for --history).
# Findings show where (file:line, and the commit for --history) with values
# masked, so a CI log never re-exposes the secret.
# A reviewed false positive is ignored when its line contains "siska:allow-secret", or when its
# location is listed in .siska/secrets-allow (one "file:line" or "commit file:line" per line,
# "# reason" comments allowed) – the only way for lines already in the history.
# A secret found in the history is compromised even if deleted since: rotate it.
# Read-only. Exit code: 0 clean, 1 possible leak found, 2 usage error or not a git repository.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

ROOT_ARG="." MODE=work RANGE="" NEXT_IS_RANGE=0
for arg in "$@"; do
  if [ $NEXT_IS_RANGE -eq 1 ]; then RANGE="$arg"; NEXT_IS_RANGE=0; continue; fi
  case "$arg" in
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --range) MODE=range; NEXT_IS_RANGE=1 ;;
    --history) MODE=history ;;
    -*) sld_die "unknown option: $arg" ;;
    *) ROOT_ARG="$arg" ;;
  esac
done
[ $NEXT_IS_RANGE -eq 0 ] || sld_die "--range needs A..B"
ROOT="$(sld_project_root "$ROOT_ARG")"
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || sld_die "not a git repository: $ROOT"
ROOT="$(git -C "$ROOT" rev-parse --show-toplevel)"
if [ "$MODE" = range ]; then
  case "$RANGE" in *..*) ;; *) sld_die "--range needs A..B (e.g. origin/main..HEAD)" ;; esac
  git -C "$ROOT" rev-parse --verify -q "${RANGE%%..*}^{commit}" >/dev/null && git -C "$ROOT" rev-parse --verify -q "${RANGE##*..}^{commit}" >/dev/null ||
    sld_die "unknown commit in range $RANGE (in CI, fetch the base branch: fetch-depth: 0)"
fi
FOUND=0
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
ADDED="$TMPD/added"   # one "location<TAB>content" line per added line
ENV_RE='(^|[/ ])\.env(\.[^/]*)?$'   # path, or "commit path" in --history
ENV_OK_RE='\.(example|sample|dist|template)$'
SENSITIVE_RE='(\.(pem|key|p12|pfx|jks|keystore|ppk|asc)|(^|/)id_(rsa|dsa|ecdsa|ed25519)|(^|/)\.htpasswd|(^|/)service-account[^/]*\.json)$'

# Unified diff (-U0) on stdin -> "file:line<TAB>content" for each added line; $1 = location prefix.
diff_to_added() {
  awk -v pre="$1" '
    /^commit [0-9a-f]+$/ { pre = $2 " "; next }
    /^\+\+\+ / { f = substr($0, 7); next }
    /^@@/ { split($3, a, ","); n = substr(a[1], 2) + 0; next }
    /^\+/ { printf "%s%s:%d\t%s\n", pre, f, n, substr($0, 2); n++ }'
}

case "$MODE" in
  work)
    # Without any commit yet, compare with the empty tree so staged files are scanned too.
    base="HEAD"
    git -C "$ROOT" rev-parse --verify -q HEAD >/dev/null || base="$(git -C "$ROOT" hash-object -t tree /dev/null)"
    untracked="$(git -C "$ROOT" ls-files --others --exclude-standard)"
    git -C "$ROOT" diff "$base" --no-color -U0 2>/dev/null | diff_to_added "" >"$ADDED"
    while IFS= read -r f; do
      # -I skips binary files.
      [ -n "$f" ] && [ -f "$ROOT/$f" ] && grep -HnI '' "$ROOT/$f" 2>/dev/null | sed -E "s|^$ROOT/||; s/^([^:]*:[0-9]+):/\1\t/" >>"$ADDED"
    done <<<"$untracked"
    added_files="$(git -C "$ROOT" diff "$base" --name-only --diff-filter=A 2>/dev/null; printf '%s\n' "$untracked")"
    envs="$(git -C "$ROOT" ls-files | grep -E "$ENV_RE" | grep -Ev "$ENV_OK_RE" || true)"
    where="changes" ;;
  range)
    git -C "$ROOT" diff "${RANGE%%..*}" "${RANGE##*..}" --no-color -U0 | diff_to_added "" >"$ADDED"
    added_files="$(git -C "$ROOT" diff "${RANGE%%..*}" "${RANGE##*..}" --name-only --diff-filter=A)"
    envs="$(printf '%s\n' "$added_files" | grep -E "$ENV_RE" | grep -Ev "$ENV_OK_RE" || true)"
    where="commits $RANGE" ;;
  history)
    sld_spin "Reading the whole git history" sh -c 'git -C "$1" log --all -p --no-color -U0 --format="commit %h" | awk "{print}" >"$2"' _ "$ROOT" "$TMPD/log"
    diff_to_added "" <"$TMPD/log" >"$ADDED"
    added_files="$(git -C "$ROOT" log --all --diff-filter=A --name-only --format='commit %h' | awk '/^commit /{c=$2; next} NF{print c " " $0}')"
    envs="$(printf '%s\n' "$added_files" | grep -E "$ENV_RE" | grep -Ev "$ENV_OK_RE" || true)"
    added_files="$(printf '%s\n' "$added_files" | sed 's/^[0-9a-f]* //')"
    where="git history ($(git -C "$ROOT" rev-list --all --count) commits)" ;;
esac

if [ -n "$envs" ]; then
  if [ "$MODE" = work ]; then label="tracked by git"; else label="in $where"; fi
  sld_info "BLOCK: environment file(s) $label: $(echo "$envs" | tr '\n' ' ')"; FOUND=1
fi
sensitive="$(printf '%s\n' "$added_files" | grep -Ei "$SENSITIVE_RE" | sort -u || true)"
if [ -n "$sensitive" ]; then
  sld_info "BLOCK: sensitive file(s) added in $where (keys, keystores, credentials): $(echo "$sensitive" | tr '\n' ' ')"; FOUND=1
fi
grep -v 'siska:allow-secret' "$ADDED" >"$TMPD/scan" || true

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

{
  grep -E -- "$token_re|$url_re" "$TMPD/scan"
  grep -Ei -- "$assign_re" "$TMPD/scan" | grep -Eiv -- "$placeholder_re"
  grep -E -- "$upper_re" "$TMPD/scan" | grep -Eiv -- "$placeholder_re"
} | sort -u >"$TMPD/leaks"
if [ -f "$ROOT/.siska/secrets-allow" ]; then
  # Reviewed locations: exact match on the location column.
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$ROOT/.siska/secrets-allow" >"$TMPD/allow"
  awk -F'\t' 'NR == FNR { ok[$0] = 1; next } !($1 in ok)' "$TMPD/allow" "$TMPD/leaks" >"$TMPD/leaks.kept"
  mv "$TMPD/leaks.kept" "$TMPD/leaks"
fi
if [ -s "$TMPD/leaks" ]; then
  sld_info "BLOCK: possible secret(s) in $where (move them to env vars / a secret manager; reviewed false positive: add a 'siska:allow-secret' comment on the line):"
  # Mask every long token of the content (keep 4 characters), so the report never re-exposes a secret.
  tok='[A-Za-z0-9+/=_-]'
  awk -F'\t' -v re="$tok$tok$tok$tok$tok$tok$tok$tok$tok*" '{
    c = substr($0, length($1) + 2); out = ""
    while (match(c, re)) { out = out substr(c, 1, RSTART - 1) substr(c, RSTART, 4) "****"; c = substr(c, RSTART + RLENGTH) }
    line = $1 "  " out c; print substr(line, 1, 200) }' "$TMPD/leaks" | head -n 200
  [ "$(wc -l <"$TMPD/leaks")" -le 200 ] || sld_info "… $(($(wc -l <"$TMPD/leaks") - 200)) more"
  [ "$MODE" != history ] || sld_info "NOTE:  values in the history stay readable in every clone even if deleted since: rotate them first. Rewriting history (git filter-repo) is a separate, high-risk step for the team."
  FOUND=1
fi

[ $FOUND -eq 0 ] && sld_info "OK:    no secret, key or sensitive file in $where"
exit $FOUND
