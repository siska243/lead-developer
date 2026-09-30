#!/usr/bin/env bash
# Performance budgets: measure pages and apps, fail when one gets heavier or slower than allowed.
#
# Usage: bash perf-budget.sh [PROJECT_DIR] run [--only NAME] [--allow-download] [--update-baseline] [--report FILE]
#        bash perf-budget.sh [PROJECT_DIR] check NAME METRICS.json [--update-baseline] [--report FILE]
#
# Budgets live in .siska/perf-budget.json (committed):
#   { "tolerance_pct": 10,
#     "pages": { "orders": { "url": "http://localhost:4173/order-v2", "desktop": true,
#                            "budget": { "api_kb": 800, "transferred_kb": 1500, "lcp_ms": 2500 } } },
#     "apps":  { "android": { "package": "com.company.app", "flow": ".maestro/orders.yaml",
#                             "budget": { "cold_start_ms": 1500, "janky_pct": 10 } } } }
# Metrics: web  score, lcp_ms, fcp_ms, tbt_ms, cls, transferred_kb, api_kb, requests, api_calls, duplicate_requests
#          mobile cold_start_ms, janky_pct, frame_p90_ms, memory_mb, cpu_pct, size_mb
# A metric fails when it passes its budget (score: when it drops below), or when it gets worse
# than the baseline (.siska/perf/<name>.json, the last accepted measure) by more than tolerance_pct.
# run measures every entry (page-scan.sh / mobile-scan.sh, same options as those scripts);
# check compares one metrics file already measured (CI, another tool).
# --update-baseline records the measures as the new baseline when they pass (after an accepted optimization).
# --report writes the visual report data for report.sh.
# Exit code: 0 within budget, 1 over budget or regression, 2 usage error or a measure failed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

ROOT_ARG="." CMD="" ONLY="" UPDATE=0 REPORT_DATA="" PASS=() POS=() NEXT=""
for arg in "$@"; do
  case "$NEXT" in
    only) ONLY="$arg"; NEXT=""; continue ;;
    report) REPORT_DATA="$arg"; NEXT=""; continue ;;
  esac
  case "$arg" in
    -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --only) NEXT=only ;;
    --report) NEXT=report ;;
    --update-baseline) UPDATE=1 ;;
    --allow-download) PASS+=("$arg") ;;
    -*) sld_die "unknown option: $arg" ;;
    run|check) [ -z "$CMD" ] && CMD="$arg" || POS+=("$arg") ;;
    *) if [ -z "$CMD" ]; then ROOT_ARG="$arg"; else POS+=("$arg"); fi ;;
  esac
done
[ -z "$NEXT" ] || sld_die "--$NEXT needs a value"
[ -n "$CMD" ] || sld_die "usage: perf-budget.sh [PROJECT_DIR] run | check NAME METRICS.json"
sld_has_cmd node || sld_die "node is required"
ROOT="$(sld_project_root "$ROOT_ARG")"
BUDGET="$ROOT/.siska/perf-budget.json"
[ -f "$BUDGET" ] || sld_die "no budget file: $BUDGET (see references/performance.md, section Performance budgets)"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT

# Entries of the budget file as "kind<TAB>name<TAB>target<TAB>extra" (extra: desktop flag or Maestro flow).
entries="$(node -e '
  let b; try { b = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); } catch (e) { console.error(`ERROR: invalid ${process.argv[1]}: ${e.message}`); process.exit(2); }
  for (const [n, p] of Object.entries(b.pages || {})) console.log(["web", n, p.url || "", p.desktop ? "desktop" : ""].join("\t"));
  for (const [n, p] of Object.entries(b.apps || {})) console.log(["mobile", n, p.package || "", p.flow || ""].join("\t"));
' "$BUDGET")" || exit 2

case "$CMD" in
  check)
    [ ${#POS[@]} -eq 2 ] || sld_die "usage: perf-budget.sh [PROJECT_DIR] check NAME METRICS.json"
    printf '%s\n' "$entries" | cut -f2 | grep -qxF -- "${POS[0]}" || sld_die "no entry named '${POS[0]}' in $BUDGET"
    [ -f "${POS[1]}" ] || sld_die "metrics file not found: ${POS[1]}"
    cp "${POS[1]}" "$TMPD/${POS[0]}.json" ;;
  run)
    [ -n "$entries" ] || sld_die "no pages nor apps in $BUDGET"
    while IFS=$'\t' read -r kind name target extra; do
      [ -z "$ONLY" ] || [ "$ONLY" = "$name" ] || continue
      sld_info "## measuring $name ($target)"
      if [ "$kind" = web ]; then
        args=("$target" --metrics "$TMPD/$name.json"); [ "$extra" = desktop ] && args+=(--desktop)
        bash "$SCRIPT_DIR/page-scan.sh" "${args[@]}" ${PASS[@]+"${PASS[@]}"} >"$TMPD/$name.log" 2>&1
      else
        args=("$target" --metrics "$TMPD/$name.json"); [ -n "$extra" ] && args+=(--flow "$ROOT/$extra")
        bash "$SCRIPT_DIR/mobile-scan.sh" "${args[@]}" >"$TMPD/$name.log" 2>&1
      fi
      if [ ! -s "$TMPD/$name.json" ]; then
        sld_info "ERROR: measure of $name failed:"; tail -n 8 "$TMPD/$name.log"; exit 2
      fi
      grep '^WARN' "$TMPD/$name.log" | sort -u
    done <<<"$entries"
    ls "$TMPD"/*.json >/dev/null 2>&1 || sld_die "no entry named '$ONLY' in $BUDGET" ;;
esac

mkdir -p "$ROOT/.siska/perf"
node - "$BUDGET" "$TMPD" "$ROOT/.siska/perf" "$UPDATE" "$REPORT_DATA" "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || true)" <<'EOF'
const fs = require("fs"), path = require("path");
const [budgetPath, dir, baseDir, update, reportPath, commit] = process.argv.slice(2);
const cfg = JSON.parse(fs.readFileSync(budgetPath, "utf8"));
const tol = Number(cfg.tolerance_pct ?? 10);
const HIGHER_IS_BETTER = new Set(["score"]);
const UNIT = { score: "/100", lcp_ms: "ms", fcp_ms: "ms", tbt_ms: "ms", cold_start_ms: "ms", frame_p90_ms: "ms", transferred_kb: "KB", api_kb: "KB", janky_pct: "%", cpu_pct: "%", memory_mb: "MB", size_mb: "MB" };
const entries = { ...(cfg.pages || {}), ...(cfg.apps || {}) };
let failed = false; const sections = []; const summary = [];

for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".json"))) {
  const name = file.replace(/\.json$/, ""), m = JSON.parse(fs.readFileSync(path.join(dir, file), "utf8"));
  const budget = (entries[name] && entries[name].budget) || {};
  const basePath = path.join(baseDir, `${name}.json`);
  const base = fs.existsSync(basePath) ? JSON.parse(fs.readFileSync(basePath, "utf8")).metrics || {} : null;
  const rows = []; let entryFailed = false;
  const keys = [...new Set([...Object.keys(budget), ...Object.keys(base || {})])].filter((k) => typeof m[k] === "number");
  console.log(`\n## ${name}${m.dev_server ? "  (dev server: figures are not production ones)" : ""}${m.emulator || m.debug_build ? "  (emulator/debug build: indicative)" : ""}`);
  for (const k of keys) {
    const v = m[k], hb = HIGHER_IS_BETTER.has(k), lim = budget[k], was = base ? base[k] : undefined;
    const over = typeof lim === "number" && (hb ? v < lim : v > lim);
    const drift = typeof was === "number" && was !== 0 ? ((v - was) / Math.abs(was)) * 100 * (hb ? -1 : 1) : 0;
    const regressed = typeof was === "number" && drift > tol;
    const status = over ? "fail" : regressed ? "warn" : "ok";
    if (over || regressed) entryFailed = true;
    const why = over ? `over budget ${lim}` : regressed ? `+${Math.round(drift)}% vs baseline ${was}` : "ok";
    console.log(`${over || regressed ? "BLOCK" : "OK   "}  ${k.padEnd(18)} ${String(v).padStart(8)} ${UNIT[k] || ""}  budget ${lim ?? "-"}  baseline ${was ?? "-"}  ${why}`);
    rows.push([k, `${v} ${UNIT[k] || ""}`.trim(), lim ?? "-", was ?? "-", { text: why, status }]);
  }
  if (!keys.length) console.log("WARN:  no budget nor baseline for this entry: nothing checked");
  if (!base) console.log(`NOTE:  no baseline yet for ${name}${update === "1" ? "" : " (record one with --update-baseline)"}`);
  failed = failed || entryFailed;
  summary.push(`${name}: ${entryFailed ? "over" : "within"} budget`);
  sections.push({ type: "table", title: `${name} · ${m.target || ""}`, columns: ["Metric", "Now", "Budget", "Baseline", "Result"], rows });
  if (update === "1" && !entryFailed) {
    fs.writeFileSync(basePath, JSON.stringify({ name, commit: commit || null, recorded_at: new Date().toISOString(), metrics: m }, null, 2) + "\n");
    console.log(`OK:    baseline recorded: .siska/perf/${name}.json`);
  }
}
console.log(`\nRESULT: ${failed ? "over budget or regression – not ready to merge" : "within budget"}`);
if (reportPath) {
  fs.writeFileSync(reportPath, JSON.stringify({
    command: "perf-budget", title: "Performance budgets", date: new Date().toISOString().slice(0, 16).replace("T", " "),
    verdict: { status: failed ? "fail" : "ok", summary: summary.join(" · ") + `. Tolerance vs baseline: ${tol}%.` },
    sections,
  }, null, 2));
}
process.exit(failed ? 1 : 0);
EOF
