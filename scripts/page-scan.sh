#!/usr/bin/env bash
# Scan one page by its URL and summarize what makes it heavy or slow.
#
# Usage: bash page-scan.sh <URL> [--allow-download] [--desktop] [--save-json FILE] [--report FILE] [--metrics FILE]
#        bash page-scan.sh <URL> --login-url <login page URL>   (with SISKA_SCAN_USER / SISKA_SCAN_PASSWORD)
#        bash page-scan.sh --login <URL> [--token-key KEY] [--ask]
#        bash page-scan.sh --logout
#        bash page-scan.sh --from-json <lighthouse-report.json>
#
# Runs Lighthouse (performance only, headless Chrome) and prints: scores and
# metrics (LCP, TBT, CLS…), transferred bytes and requests per type, heaviest
# resources, API calls (fetch/XHR), requests made more than once, and the
# Lighthouse opportunities with their estimated savings. --save-json keeps the
# raw report (before/after comparison); --report writes the visual report data
# (templates/report/README.md) for scripts/report.sh; --metrics writes the flat numbers
# (score, lcp_ms, tbt_ms, cls, transferred_kb, api_kb, requests, duplicate_requests…) for perf-budget.sh.
# Lighthouse: the installed `lighthouse` binary, else `npx lighthouse` only with
# --allow-download (the agent asks the user first).
# Pages behind a login (dedicated Chrome profile $SISKA_CHROME_PROFILE, default
# ~/.cache/siska/chrome-profile, mode 700, outside the project; --logout closes and deletes it):
#   credentials:  SISKA_SCAN_USER=… SISKA_SCAN_PASSWORD=… page-scan.sh <URL> --login-url <login URL>
#                 logs in and measures in the same headless Chrome (works with session cookies);
#                 --ask prompts for them, password hidden, when run in a terminal.
#   token:        SISKA_SCAN_TOKEN=… page-scan.sh <URL> --token-key <localStorage key the front reads>
#   manual:       page-scan.sh --login <URL> opens a visible Chrome with remote debugging: log in and
#                 leave it open; each scan copies its session (cookies, localStorage) into a throwaway
#                 headless Chrome (captcha, 2FA). Close it or --logout afterwards.
#   persistent:   --login with the token or credentials variables stores what survives a restart
#                 (localStorage, cookies with an expiry) for later scans.
#   one header:   SISKA_SCAN_HEADER='Authorization: Bearer …' on the scan itself.
# Secrets come from the environment only (never arguments), are never printed or
# saved; only the resulting session is kept. Use a test account, not an admin.
# A scan that hangs (Lighthouse 13 insights on very large traces) is stopped after 180 s and
# retried once with metrics, requests and weight only. Dev servers (Vite, webpack, next dev) are
# measured that way from the start, without throttling. --desktop for desktop web apps (back offices).
# Read-only: one page load, like a visitor. Exit code: 0 ok, 1 scan failed, 2 usage error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

URL="" REPORT="" SAVE="" REPORT_DATA="" METRICS="" TOKEN_KEY="" LOGIN_URL="" ALLOW_DOWNLOAD=0 LOGIN=0 LOGOUT=0 ASK=0 PRESET="" NEXT=""
for arg in "$@"; do
  case "$NEXT" in
    json) REPORT="$arg"; NEXT=""; continue ;;
    save) SAVE="$arg"; NEXT=""; continue ;;
    report) REPORT_DATA="$arg"; NEXT=""; continue ;;
    metrics) METRICS="$arg"; NEXT=""; continue ;;
    key) TOKEN_KEY="$arg"; NEXT=""; continue ;;
    loginurl) LOGIN_URL="$arg"; NEXT=""; continue ;;
  esac
  case "$arg" in
    -h|--help) sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --from-json) NEXT=json ;;
    --save-json) NEXT=save ;;
    --report) NEXT=report ;;
    --metrics) NEXT=metrics ;;
    --allow-download) ALLOW_DOWNLOAD=1 ;;
    --login) LOGIN=1 ;;
    --logout) LOGOUT=1 ;;
    --ask) ASK=1 ;;
    --token-key) NEXT=key ;;
    --login-url) NEXT=loginurl ;;
    --desktop) PRESET="--preset=desktop" ;;
    -*) sld_die "unknown option: $arg" ;;
    *) URL="$arg" ;;
  esac
done
[ -z "$NEXT" ] || sld_die "--from-json, --save-json, --report, --metrics and --token-key need a value"
sld_has_cmd node || sld_die "node is required to read the Lighthouse report"
PROFILE="${SISKA_CHROME_PROFILE:-${SLD_HOME:-$HOME}/.cache/siska/chrome-profile}"

find_chrome() {
  local c
  [ -n "${CHROME_PATH:-}" ] && { echo "$CHROME_PATH"; return; }
  for c in google-chrome google-chrome-stable chromium chromium-browser; do sld_has_cmd "$c" && { echo "$c"; return; }; done
  sld_die "Chrome not found: set CHROME_PATH"
}
# Port of a Chrome that is running on the profile with remote debugging (the --login window), if any.
live_port() {
  local lock port
  lock="$(readlink "$PROFILE/SingletonLock" 2>/dev/null || true)"
  [ -n "$lock" ] && kill -0 "${lock##*-}" 2>/dev/null || return 1
  port="$(head -n 1 "$PROFILE/DevToolsActivePort" 2>/dev/null || true)"
  [ -n "$port" ] && curl -s --max-time 3 "http://127.0.0.1:$port/json/version" >/dev/null 2>&1 && echo "$port"
}

if [ $LOGOUT -eq 1 ]; then
  lock="$(readlink "$PROFILE/SingletonLock" 2>/dev/null || true)"
  [ -n "$lock" ] && kill "${lock##*-}" 2>/dev/null && sleep 2
  rm -rf "$PROFILE"; sld_info "OK:    scan session closed and deleted ($PROFILE)"; exit 0
fi

TMPD="$(mktemp -d)"
STARTED_PID=""
cleanup() {
  if [ -n "$STARTED_PID" ]; then
    kill -- "-$STARTED_PID" 2>/dev/null
    # Chrome writes its profile while exiting; wait before deleting the throwaway copy.
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$STARTED_PID" 2>/dev/null || break; sleep 0.5; done
  fi
  rm -rf "$TMPD" 2>/dev/null || { sleep 1; rm -rf "$TMPD"; }
}
trap cleanup EXIT

if [ -z "$REPORT" ]; then
  case "$URL" in http://*|https://*) ;; *) sld_die "give a page URL (http:// or https://), or --from-json <report>" ;; esac
  [ -z "${SISKA_SCAN_TOKEN:-}" ] || [ -n "$TOKEN_KEY" ] || sld_die "SISKA_SCAN_TOKEN needs --token-key <localStorage key the front end reads>"
  if [ $ASK -eq 1 ] && [ -t 0 ]; then
    read -r -p "Login (test account): " SISKA_SCAN_USER
    read -r -s -p "Password: " SISKA_SCAN_PASSWORD; echo
    export SISKA_SCAN_USER SISKA_SCAN_PASSWORD
  fi
  HAS_CREDS=0; [ -n "${SISKA_SCAN_USER:-}" ] && [ -n "${SISKA_SCAN_PASSWORD:-}" ] && HAS_CREDS=1

  if [ $LOGIN -eq 1 ]; then
    chrome="$(find_chrome)" || exit 2
    mkdir -p "$PROFILE" && chmod 700 "$PROFILE"
    if [ -n "${SISKA_SCAN_TOKEN:-}" ]; then
      sld_spin "Storing the token in the app" node "$SCRIPT_DIR/browser-session.js" "$chrome" "$PROFILE" "$URL" token "$TOKEN_KEY"; exit $?
    elif [ $HAS_CREDS -eq 1 ]; then
      sld_spin "Logging in" node "$SCRIPT_DIR/browser-session.js" "$chrome" "$PROFILE" "$URL" form; status=$?
      [ $status -eq 0 ] && sld_info "NOTE:  a session kept in cookies without expiry dies with Chrome; if the scan is still logged out, pass the same variables with --login-url on the scan itself."
      exit $status
    fi
    live_port >/dev/null && { sld_info "OK:    the session window is already open; scans use it"; exit 0; }
    # Visible window with remote debugging (localhost only), so scans run inside this logged-in browser.
    nohup "$chrome" --user-data-dir="$PROFILE" --remote-debugging-port=0 --no-first-run --new-window "$URL" >/dev/null 2>&1 &
    sld_info "Log in in the Chrome window that opened and LEAVE IT OPEN: scans run inside it, so even session cookies work."
    sld_info "While it is open, local programs can drive it through its debugging port: close it, or run --logout, when the work is done."
    exit 0
  fi

  if sld_has_cmd lighthouse; then LH=(lighthouse)
  elif [ $ALLOW_DOWNLOAD -eq 1 ]; then LH=(npx --yes lighthouse)
  else sld_die "lighthouse is not installed. Install it (npm i -g lighthouse) or re-run with --allow-download (downloads it with npx)"
  fi
  extra=() connect=() flags="--headless=new"
  if src="$(live_port)"; then
    # Copy the open --login window's session into a throwaway headless Chrome: a visible window in
    # the background does not paint (NO_FCP), and the user's window stays untouched.
    chrome="$(find_chrome)" || exit 2
    out="$(sld_spin "Copying the session of the open window" node "$SCRIPT_DIR/browser-session.js" "$chrome" "$TMPD/clone-profile" "$URL" clone "$src" --keep)" || { printf '%s\n' "$out"; exit 1; }
    read -r port STARTED_PID <<<"$(printf '%s\n' "$out" | tail -n 1)"
    printf '%s\n' "$out" | sed '$d'
    connect=(--port="$port"); extra+=(--disable-storage-reset)
  elif [ -n "${SISKA_SCAN_TOKEN:-}" ] || [ $HAS_CREDS -eq 1 ]; then
    # Log in and measure in the same headless Chrome, so session cookies survive until the measure.
    chrome="$(find_chrome)" || exit 2
    mkdir -p "$PROFILE" && chmod 700 "$PROFILE"
    if [ -n "${SISKA_SCAN_TOKEN:-}" ]; then mode=(token "$TOKEN_KEY"); target="$URL"
    else mode=(form); target="${LOGIN_URL:-}"; [ -n "$target" ] || sld_die "credentials need --login-url <login page URL>"
    fi
    out="$(sld_spin "Logging in" node "$SCRIPT_DIR/browser-session.js" "$chrome" "$PROFILE" "$target" "${mode[@]}" --keep)" || { printf '%s\n' "$out"; exit 1; }
    read -r port STARTED_PID <<<"$(printf '%s\n' "$out" | tail -n 1)"
    printf '%s\n' "$out" | sed '$d'
    connect=(--port="$port"); extra+=(--disable-storage-reset)
  elif [ -d "$PROFILE" ]; then
    lock="$(readlink "$PROFILE/SingletonLock" 2>/dev/null || true)"
    if [ -n "$lock" ] && kill -0 "${lock##*-}" 2>/dev/null; then
      sld_die "a Chrome window without remote debugging holds the session profile (pid ${lock##*-}): close it and run --login again"
    fi
    # Persistent session from --login (localStorage, cookies with an expiry).
    flags="$flags --user-data-dir=$PROFILE"; extra+=(--disable-storage-reset)
  fi
  if [ -n "${SISKA_SCAN_HEADER:-}" ]; then
    (umask 077; SISKA_SCAN_HEADER="$SISKA_SCAN_HEADER" node -e '
      const h = process.env.SISKA_SCAN_HEADER, i = h.indexOf(":");
      if (i < 1) { console.error("SISKA_SCAN_HEADER must look like \"Name: value\""); process.exit(2); }
      require("fs").writeFileSync(process.argv[1], JSON.stringify({ [h.slice(0, i).trim()]: h.slice(i + 1).trim() }));
    ' "$TMPD/headers.json") || exit 2
    extra+=(--extra-headers="$TMPD/headers.json")
  fi
  REPORT="$TMPD/report.json"
  run_lh() { # extra lighthouse flags...
    local how=(--chrome-flags="$flags"); [ ${#connect[@]} -eq 0 ] || how=("${connect[@]}")
    # shellcheck disable=SC2086 # PRESET is empty or one flag
    sld_timeout 180 "${LH[@]}" "$URL" --only-categories=performance --output=json --output-path="$REPORT" \
      "${how[@]}" --max-wait-for-load=45000 --quiet $PRESET ${extra[@]+"${extra[@]}"} "$@" >"$TMPD/lh.log" 2>&1
  }
  sld_info "scanning $URL (one page load)…"
  first=()
  # Metrics, requests and weight only: Lighthouse 13 insights can hang on huge traces (dev servers, thousands of requests).
  LEAN="--only-audits=first-contentful-paint,largest-contentful-paint,total-blocking-time,cumulative-layout-shift,speed-index,interactive,network-requests,total-byte-weight,mainthread-work-breakdown,bootup-time,dom-size"
  # Dev servers serve hundreds of unbundled modules, on which the network simulation never ends.
  if sld_has_cmd curl && curl -s --max-time 10 "$URL" | grep -Eq '/@vite/client|/@react-refresh|webpack-dev-server|/_next/static/development/'; then
    # Real throttling (devtools) on hundreds of modules outlasts the load window (NO_FCP): measure unthrottled.
    sld_info "WARN:  development server detected – measuring without throttling (figures are dev-server figures, not production ones)"
    first=(--throttling-method=provided "$LEAN")
  fi
  sld_spin "Lighthouse is loading the page" run_lh ${first[@]+"${first[@]}"}; status=$?
  if [ $status -eq 124 ]; then
    # timeout does not reach Lighthouse's node process nor a Chrome it launched (own process group): stop them
    # so the retry can start. A Chrome we connected to (--port) is left running.
    for sig in TERM KILL; do
      pkill "-$sig" -f -- "--output-path=$REPORT" 2>/dev/null; pkill "-$sig" -f -- "--user-data-dir=/tmp/lighthouse\." 2>/dev/null
      [ ${#connect[@]} -gt 0 ] || pkill "-$sig" -f -- "--user-data-dir=$PROFILE" 2>/dev/null
      sleep 2
    done
    sld_info "WARN:  the full audit did not finish in 180 s – retrying with metrics, requests and weight only"
    sld_spin "Lighthouse is loading the page (lean audit)" run_lh --throttling-method=devtools "$LEAN"; status=$?
  fi
  if [ $status -ne 0 ] && [ ! -s "$REPORT" ]; then
    sld_info "ERROR: Lighthouse failed (exit $status):"; tail -n 15 "$TMPD/lh.log"; exit 1
  fi
fi
[ -f "$REPORT" ] || sld_die "report not found: $REPORT"
[ -z "$SAVE" ] || cp "$REPORT" "$SAVE"

node - "$REPORT" "$REPORT_DATA" "$METRICS" <<'EOF'
const r = JSON.parse(require("fs").readFileSync(process.argv[2], "utf8"));
const warns = [];
const origLog = console.log;
console.log = (line) => { if (/^WARN:/.test(line)) warns.push(line.replace(/^WARN:\s*/, "")); origLog(line); };
const a = r.audits || {};
const kb = (b) => (b > 0 && b < 1024 ? "<1 KB" : `${Math.round((b || 0) / 1024)} KB`);
const val = (id) => (a[id] && a[id].displayValue) || "-";
if (r.runtimeError && r.runtimeError.code) console.log(`WARN:  Lighthouse: ${r.runtimeError.code} ${r.runtimeError.message || ""}`);

console.log(`## Page\n${r.finalDisplayedUrl || r.finalUrl || r.requestedUrl}`);
if ((r.finalDisplayedUrl || r.finalUrl) && r.requestedUrl && (r.finalDisplayedUrl || r.finalUrl) !== r.requestedUrl)
  console.log(`WARN:  redirected from ${r.requestedUrl} (login page? create a session first: page-scan.sh --login, with a token or test credentials)`);
if (r.runtimeError && r.runtimeError.code === "NO_FCP")
  console.log("WARN:  the page painted nothing – usually a login wall or a front-end error. Create a session with --login (token, test credentials or manual), then scan again.");
const reqs = (a["network-requests"] && a["network-requests"].details && a["network-requests"].details.items) || [];
if (reqs.some((i) => /\/@vite\/client|\/@react-refresh|webpack-dev-server|\/_next\/static\/development\//.test(i.url)))
  console.log("WARN:  development server: code is not bundled or minified, so weight and timings are not production figures. Scan a production build (vite build && vite preview, next build && next start) or staging.");
const score = r.categories && r.categories.performance && r.categories.performance.score;
console.log(`performance score: ${score == null ? "-" : Math.round(score * 100)}/100`);
console.log(`LCP ${val("largest-contentful-paint")} · FCP ${val("first-contentful-paint")} · TBT ${val("total-blocking-time")} · CLS ${val("cumulative-layout-shift")} · Speed Index ${val("speed-index")}`);

const items = (a["network-requests"] && a["network-requests"].details && a["network-requests"].details.items) || [];
const total = items.reduce((s, i) => s + (i.transferSize || 0), 0);
console.log(`\n## Requests\n${items.length} requests · ${kb(total)} transferred`);
const byType = {};
for (const i of items) { const t = i.resourceType || "Other"; (byType[t] ||= { n: 0, b: 0 }); byType[t].n++; byType[t].b += i.transferSize || 0; }
for (const [t, v] of Object.entries(byType).sort((x, y) => y[1].b - x[1].b)) console.log(`- ${t}: ${v.n} · ${kb(v.b)}`);

console.log("\n## Heaviest resources");
for (const i of [...items].sort((x, y) => (y.transferSize || 0) - (x.transferSize || 0)).slice(0, 10))
  console.log(`- ${kb(i.transferSize)}  ${i.resourceType || "-"}  ${i.url.slice(0, 140)}`);

const api = items.filter((i) => i.resourceType === "XHR" || i.resourceType === "Fetch");
console.log(`\n## API calls (fetch/XHR): ${api.length}`);
for (const i of api) console.log(`- ${i.statusCode || "-"}  ${kb(i.transferSize)}  ${i.url.slice(0, 160)}`);

const seen = {};
// CORS preflights (OPTIONS) share the URL of their request: not duplicates made by the app.
for (const i of items) if (i.resourceType !== "Preflight") seen[i.url] = (seen[i.url] || 0) + 1;
const dup = Object.entries(seen).filter(([, n]) => n > 1);
console.log(`\n## Requested more than once: ${dup.length}`);
for (const [u, n] of dup) console.log(`- ${n}x  ${u.slice(0, 160)}`);

console.log("\n## Lighthouse opportunities");
// Lighthouse <= 12: details.overallSavings*; Lighthouse 13 insights: metricSavings per metric.
const savingsMs = (x) => Math.max(x.details?.overallSavingsMs || 0, ...Object.values(x.metricSavings || {}).map(Number).filter((n) => n > 0), 0);
const savingsBytes = (x) => x.details?.overallSavingsBytes || 0;
const opp = Object.values(a)
  .filter((x) => x.score != null && x.score < 0.9 && (savingsMs(x) > 0 || savingsBytes(x) > 0))
  .sort((x, y) => savingsMs(y) - savingsMs(x) || savingsBytes(y) - savingsBytes(x));
if (!opp.length) console.log("- none reported");
for (const x of opp) {
  const s = [];
  if (savingsMs(x) > 0) s.push(`~${Math.round(savingsMs(x))} ms`);
  if (savingsBytes(x) > 0) s.push(`~${kb(savingsBytes(x))}`);
  else if (x.displayValue && !/\d\s*ms$/.test(x.displayValue)) s.push(x.displayValue);
  console.log(`- ${x.title} (${s.join(", ")}) [${x.id}]`);
}

if (process.argv[3]) {
  const url = r.requestedUrl || r.finalDisplayedUrl || r.finalUrl;
  const pct = score == null ? null : Math.round(score * 100);
  const grade = (v, ok, warn) => (v == null ? "info" : v <= ok ? "ok" : v <= warn ? "warn" : "fail");
  const num = (id) => (a[id] && typeof a[id].numericValue === "number" ? a[id].numericValue : null);
  const lcp = num("largest-contentful-paint"), tbt = num("total-blocking-time"), cls = num("cumulative-layout-shift");
  // Lean audits (dev servers, huge pages) have no overall score: judge on LCP then.
  const verdict = pct != null ? (pct >= 90 ? "ok" : pct >= 50 ? "warn" : "fail") : lcp != null ? grade(lcp, 2500, 4000) : "fail";
  const data = {
    command: "optimize", title: `Page scan: ${url.replace(/^https?:\/\/[^/]+/, "") || "/"}`, target: url,
    date: (r.fetchTime || new Date().toISOString()).slice(0, 16).replace("T", " "),
    verdict: { status: verdict, summary: `${items.length} requests, ${kb(total)} transferred, ${api.length} API calls, ${dup.length} requested more than once.` + (warns.length ? " " + warns.join(" ") : "") },
    metrics: [
      { label: "Score", value: pct == null ? "–" : pct, unit: "/100", status: verdict },
      { label: "LCP", value: lcp == null ? "–" : (lcp / 1000).toFixed(1), unit: "s", status: grade(lcp, 2500, 4000) },
      { label: "TBT", value: tbt == null ? "–" : Math.round(tbt), unit: "ms", status: grade(tbt, 200, 600) },
      { label: "CLS", value: cls == null ? "–" : cls.toFixed(2), status: grade(cls, 0.1, 0.25) },
      { label: "Transferred", value: Math.round(total / 1024), unit: "KB", status: grade(total / 1024, 1600, 4000) },
      { label: "Requests", value: items.length, status: grade(items.length, 50, 120) },
    ],
    sections: [
      { type: "table", title: "Weight by type", columns: ["Type", "Requests", "Transferred"],
        rows: Object.entries(byType).sort((x, y) => y[1].b - x[1].b).map(([t, v]) => [t, v.n, kb(v.b)]) },
      { type: "table", title: "API calls", columns: ["Status", "Size", "URL"], rows: api.map((i) => [String(i.statusCode || "-"), kb(i.transferSize), i.url]) },
      { type: "table", title: "Requested more than once", columns: ["Times", "URL"], rows: dup.map(([u, n]) => [n, u]) },
      { type: "findings", title: "Lighthouse opportunities", items: opp.map((x) => ({
        severity: savingsMs(x) >= 1000 ? "high" : savingsMs(x) >= 300 ? "medium" : "low", title: x.title, where: x.id,
        impact: [savingsMs(x) > 0 ? `~${Math.round(savingsMs(x))} ms` : "", savingsBytes(x) > 0 ? `~${kb(savingsBytes(x))}` : /\d\s*ms$/.test(x.displayValue || "") ? "" : x.displayValue || ""].filter(Boolean).join(", ") })) },
      { type: "table", title: "Heaviest resources", columns: ["Size", "Type", "URL"],
        rows: [...items].sort((x, y) => (y.transferSize || 0) - (x.transferSize || 0)).slice(0, 10).map((i) => [kb(i.transferSize), i.resourceType || "-", i.url]) },
    ].filter((sec) => (sec.rows || sec.items).length),
  };
  if (warns.length) data.sections.push({ type: "notes", title: "Warnings", items: warns });
  require("fs").writeFileSync(process.argv[3], JSON.stringify(data, null, 2));
}
if (process.argv[4]) {
  const num = (id) => (a[id] && typeof a[id].numericValue === "number" ? a[id].numericValue : null);
  const round = (v, d = 0) => (v == null ? null : Math.round(v * 10 ** d) / 10 ** d);
  const apiBytes = api.reduce((sum, i) => sum + (i.transferSize || 0), 0);
  require("fs").writeFileSync(process.argv[4], JSON.stringify({
    kind: "web", target: r.requestedUrl || r.finalDisplayedUrl, measured_at: r.fetchTime || new Date().toISOString(),
    score: score == null ? null : Math.round(score * 100), lcp_ms: round(num("largest-contentful-paint")), fcp_ms: round(num("first-contentful-paint")),
    tbt_ms: round(num("total-blocking-time")), cls: round(num("cumulative-layout-shift"), 3), transferred_kb: Math.round(total / 1024),
    api_kb: Math.round(apiBytes / 1024), requests: items.length, api_calls: api.length, duplicate_requests: dup.length,
    dev_server: warns.some((w) => /development server/.test(w)),
  }, null, 2));
}
EOF
