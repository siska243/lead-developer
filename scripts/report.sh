#!/usr/bin/env bash
# Build the visual report of a command result, and print its terminal summary.
#
# Usage: bash report.sh <data.json> --out <file.html> [--standalone]
#
# <data.json> follows templates/report/README.md (verdict, metrics, tables,
# findings, before/after, notes). Writes the page from templates/report/report.html:
#   default       page body, ready to publish as a rich page (e.g. an artifact);
#   --standalone  complete HTML document to open in a browser (prints its file:// link).
# Prints a short summary (verdict, metrics) – coloured when the terminal supports it.
# The data is embedded as JSON (with "<" escaped) and rendered as text only.
# Exit code: 0 written, 2 usage or invalid data.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

DATA="" OUT="" STANDALONE=0 NEXT_IS_OUT=0
for arg in "$@"; do
  if [ $NEXT_IS_OUT -eq 1 ]; then OUT="$arg"; NEXT_IS_OUT=0; continue; fi
  case "$arg" in
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --out) NEXT_IS_OUT=1 ;;
    --standalone) STANDALONE=1 ;;
    -*) sld_die "unknown option: $arg" ;;
    *) DATA="$arg" ;;
  esac
done
[ -f "$DATA" ] || sld_die "report data not found: ${DATA:-<none>}"
[ -n "$OUT" ] || sld_die "--out <file.html> is required"
sld_has_cmd node || sld_die "node is required to build the report"
mkdir -p "$(dirname "$OUT")"

COLOR=0; [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && COLOR=1
node - "$DATA" "$SCRIPT_DIR/../templates/report/report.html" "$OUT" "$STANDALONE" "$COLOR" <<'JS'
const fs = require("fs");
const [dataPath, tplPath, out, standalone, color] = process.argv.slice(2);
let data;
try { data = JSON.parse(fs.readFileSync(dataPath, "utf8")); } catch (e) { console.error(`ERROR: invalid report JSON: ${e.message}`); process.exit(2); }
if (!data.title) { console.error("ERROR: report JSON needs a \"title\""); process.exit(2); }
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const json = JSON.stringify(data).replace(/</g, "\\u003c").replace(/\u2028/g, "\\u2028").replace(/\u2029/g, "\\u2029");
let page = fs.readFileSync(tplPath, "utf8").replace("__SISKA_TITLE__", () => esc(data.title)).replace("__SISKA_DATA__", () => json);
if (standalone === "1")
  page = `<!doctype html>\n<html lang="${esc(data.lang || "en")}">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n</head>\n<body>\n${page}\n</body>\n</html>\n`;
fs.writeFileSync(out, page);

const c = color === "1", paint = (code, s) => (c ? `\x1b[${code}m${s}\x1b[0m` : s);
const ICON = { ok: ["32", "✔"], warn: ["33", "⚠"], fail: ["31", "✖"], info: ["36", "ℹ"] };
const st = (data.verdict && ICON[data.verdict.status]) ? data.verdict.status : "info";
console.log(paint("1", `${paint(ICON[st][0], ICON[st][1])} ${data.title}`) + (data.verdict && data.verdict.summary ? ` — ${data.verdict.summary}` : ""));
for (const m of data.metrics || []) {
  const s = ICON[m.status] ? m.status : "info";
  console.log(`  ${paint(ICON[s][0], "●")} ${m.label}: ${m.before != null ? `${m.before} → ` : ""}${m.value}${m.unit ? " " + m.unit : ""}`);
}
if (standalone === "1") console.log(`report: file://${require("path").resolve(out)}`);
else console.log(`report page: ${out} (publish it and show the link)`);
JS
