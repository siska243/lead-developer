#!/usr/bin/env bash
# Measure an Android app on a device or emulator and summarize what makes it slow.
#
# Usage: bash mobile-scan.sh <android package> [--flow maestro.yaml] [--runs N] [--serial ID] [--report FILE]
#
# Standard Android platform tools only (adb, am, dumpsys), plus Maestro when a flow is given:
#   - cold start: `am start -W -S`, median of --runs (default 3);
#   - smoothness while the screen is used: `dumpsys gfxinfo` (frames, janky %, frame time
#     percentiles) during the Maestro flow, or during a few scrolls when no flow is given;
#   - memory (`dumpsys meminfo`, total PSS), CPU (`dumpsys cpuinfo`), installed size (APKs).
# --report writes the visual report data (templates/report/README.md) for scripts/report.sh.
# Works with release and debug builds; measure a release build (debug/dev bundles are much slower).
# For pages behind a login, log in inside the flow (Maestro) with a test account.
# Read-only on the project; on the device it only launches and stops the app.
# Exit code: 0 measured, 1 measure failed, 2 usage error (no adb, no device, unknown package).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

PKG="" FLOW="" RUNS=3 SERIAL="" REPORT_DATA="" NEXT=""
for arg in "$@"; do
  case "$NEXT" in
    flow) FLOW="$arg"; NEXT=""; continue ;;
    runs) RUNS="$arg"; NEXT=""; continue ;;
    serial) SERIAL="$arg"; NEXT=""; continue ;;
    report) REPORT_DATA="$arg"; NEXT=""; continue ;;
  esac
  case "$arg" in
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --flow) NEXT=flow ;;
    --runs) NEXT=runs ;;
    --serial) NEXT=serial ;;
    --report) NEXT=report ;;
    -*) sld_die "unknown option: $arg" ;;
    *) PKG="$arg" ;;
  esac
done
[ -z "$NEXT" ] || sld_die "--$NEXT needs a value"
[[ "$PKG" =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$ ]] || sld_die "give the Android package name (e.g. com.company.app; Expo: android.package in app.json)"
[[ "$RUNS" =~ ^[1-9][0-9]?$ ]] || sld_die "--runs must be 1-99"
[ -z "$FLOW" ] || [ -f "$FLOW" ] || sld_die "Maestro flow not found: $FLOW"
sld_has_cmd adb || { [ -x "${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb" ] && PATH="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools:$PATH"; } || sld_die "adb not found (Android SDK platform-tools)"
[ -z "$FLOW" ] || sld_has_cmd maestro || [ -x "$HOME/.maestro/bin/maestro" ] || sld_die "maestro not found (needed for --flow)"
MAESTRO="$(command -v maestro || echo "$HOME/.maestro/bin/maestro")"

ADB=(adb); [ -z "$SERIAL" ] || ADB=(adb -s "$SERIAL")
sh_() { "${ADB[@]}" shell "$@" 2>/dev/null | tr -d '\r'; }
[ "$(sh_ getprop sys.boot_completed)" = 1 ] || sld_die "no booted Android device or emulator (adb devices; start one, or pass --serial)"
sh_ pm path "$PKG" | grep -q '^package:' || sld_die "package $PKG is not installed on the device"

TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
model="$(sh_ getprop ro.product.model)"; release="$(sh_ getprop ro.build.version.release)"
debuggable="$(sh_ dumpsys package "$PKG" | grep -c 'pkgFlags=.*DEBUGGABLE' || true)"
sld_info "## App"
sld_info "$PKG on $model (Android $release)$([ "$debuggable" -gt 0 ] && echo ' – DEBUG build')"
[ "$debuggable" -gt 0 ] && sld_info "WARN:  debuggable build: timings are much worse than a release build; measure a release build for real figures."
emulator=0; [ "$(sh_ getprop ro.kernel.qemu)" = 1 ] || [ "$(sh_ getprop ro.boot.qemu)" = 1 ] && emulator=1
[ $emulator -eq 1 ] && sld_info "WARN:  emulator: figures are indicative only (no real GPU, host CPU); confirm on a real mid-range phone."

# Cold start: launcher activity, force-stop before each run (-S).
component="$(sh_ cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PKG" | tail -n 1)"
[[ "$component" == */* ]] || sld_die "no launcher activity found for $PKG"
starts=()
for i in $(seq "$RUNS"); do
  t="$(sh_ am start -W -S -n "$component" | sed -n 's/^TotalTime: *//p')"
  [ -n "$t" ] && starts+=("$t")
  sleep 2
done
cold="$(printf '%s\n' "${starts[@]}" | sort -n | awk '{a[NR]=$1} END {if (NR) print a[int((NR+1)/2)]}')"

# Smoothness while the app is used.
sh_ dumpsys gfxinfo "$PKG" reset >/dev/null
if [ -n "$FLOW" ]; then
  sld_info "running Maestro flow $FLOW…"
  if ! sld_spin "Maestro flow" "$MAESTRO" ${SERIAL:+--device "$SERIAL"} test "$FLOW" >"$TMPD/maestro.log" 2>&1; then
    sld_info "WARN:  Maestro flow failed: frame figures cover only what ran"; tail -n 5 "$TMPD/maestro.log"
  fi
else
  size="$(sh_ wm size | sed -n 's/.*: *\([0-9]*\)x\([0-9]*\).*/\1 \2/p' | tail -n 1)"; w="${size% *}"; h="${size#* }"
  for _ in 1 2 3; do sh_ input swipe "$((w / 2))" "$((h * 3 / 4))" "$((w / 2))" "$((h / 4))" 300; sleep 1; done
  for _ in 1 2 3; do sh_ input swipe "$((w / 2))" "$((h / 4))" "$((w / 2))" "$((h * 3 / 4))" 300; sleep 1; done
fi
sh_ dumpsys gfxinfo "$PKG" >"$TMPD/gfx.txt"
sh_ dumpsys meminfo "$PKG" >"$TMPD/mem.txt"
sh_ dumpsys cpuinfo >"$TMPD/cpu.txt"
apk_bytes=0
while IFS= read -r apk; do
  b="$(sh_ stat -c %s "${apk#package:}")"; [ -n "$b" ] && apk_bytes=$((apk_bytes + b))
done < <(sh_ pm path "$PKG")

node - "$TMPD" "$PKG" "$model" "$release" "$debuggable" "${cold:-}" "$apk_bytes" "${starts[*]:-}" "$REPORT_DATA" "${FLOW:-}" "$emulator" <<'EOF'
const fs = require("fs");
const [dir, pkg, model, release, debug, cold, apk, starts, reportPath, flow, emu] = process.argv.slice(2);
const gfx = fs.readFileSync(`${dir}/gfx.txt`, "utf8"), mem = fs.readFileSync(`${dir}/mem.txt`, "utf8"), cpu = fs.readFileSync(`${dir}/cpu.txt`, "utf8");
const grab = (re, s = gfx) => { const m = s.match(re); return m ? Number(m[1]) : null; };
const frames = grab(/Total frames rendered:\s*(\d+)/), janky = grab(/Janky frames:\s*\d+\s*\(([\d.]+)%\)/);
const p50 = grab(/50th percentile:\s*(\d+)ms/), p90 = grab(/90th percentile:\s*(\d+)ms/), p99 = grab(/99th percentile:\s*(\d+)ms/);
const pss = grab(/TOTAL PSS:\s*(\d+)/, mem) ?? grab(/^\s*TOTAL\s+(\d+)/m, mem);
const cpuLine = (cpu.split("\n").find((l) => l.includes(pkg)) || "").trim();
const cpuPct = cpuLine ? Number(cpuLine.split("%")[0]) : null;
const coldMs = cold ? Number(cold) : null;
const mb = (kb) => (kb == null ? "-" : `${Math.round(kb / 1024)} MB`);
const warns = [];
if (debug !== "0") warns.push("Debuggable build: timings are much worse than a release build; measure a release build for real figures.");
if (emu === "1") warns.push("Emulator: figures are indicative only (no real GPU, host CPU); confirm on a real mid-range phone.");
if (!frames) warns.push("No frame rendered during the measure: the screen did not move (give a Maestro flow with --flow).");

console.log(`cold start: ${coldMs ?? "-"} ms (runs: ${starts || "-"})`);
console.log(`frames: ${frames ?? "-"} · janky: ${janky ?? "-"}% · frame time p50 ${p50 ?? "-"} ms · p90 ${p90 ?? "-"} ms · p99 ${p99 ?? "-"} ms`);
console.log(`memory (PSS): ${mb(pss)} · CPU (recent): ${cpuPct ?? "-"}% · installed size: ${Math.round(Number(apk) / 1048576)} MB`);

if (reportPath) {
  const grade = (v, ok, warn) => (v == null ? "info" : v <= ok ? "ok" : v <= warn ? "warn" : "fail");
  const st = [grade(coldMs, 1000, 2000), grade(janky, 5, 15), grade(p90, 16, 32)];
  const verdict = st.includes("fail") ? "fail" : st.includes("warn") ? "warn" : st.every((x) => x === "ok") ? "ok" : "info";
  const data = {
    command: "optimize", title: `Mobile scan: ${pkg}`, target: `${model} · Android ${release}`, date: new Date().toISOString().slice(0, 16).replace("T", " "),
    verdict: { status: verdict, summary: `Cold start ${coldMs ?? "-"} ms, ${janky ?? "-"}% janky frames${flow ? ` during ${require("path").basename(flow)}` : " while scrolling"}, ${mb(pss)} of memory.` + (warns.length ? " " + warns.join(" ") : "") },
    metrics: [
      { label: "Cold start", value: coldMs ?? "–", unit: "ms", status: st[0] },
      { label: "Janky frames", value: janky ?? "–", unit: "%", status: st[1] },
      { label: "Frame time p90", value: p90 ?? "–", unit: "ms", status: st[2] },
      { label: "Memory (PSS)", value: pss == null ? "–" : Math.round(pss / 1024), unit: "MB", status: grade(pss && pss / 1024, 250, 400) },
      { label: "CPU", value: cpuPct ?? "–", unit: "%", status: grade(cpuPct, 30, 60) },
      { label: "Installed size", value: Math.round(Number(apk) / 1048576), unit: "MB", status: "info" },
    ],
    sections: [
      { type: "table", title: "Frames", columns: ["Measure", "Value"], rows: [["Frames rendered", frames ?? "-"], ["Janky frames", janky == null ? "-" : `${janky}%`], ["p50", p50 == null ? "-" : `${p50} ms`], ["p90", p90 == null ? "-" : `${p90} ms`], ["p99", p99 == null ? "-" : `${p99} ms`]] },
      { type: "table", title: "Cold start runs", columns: ["Run", "TotalTime"], rows: (starts ? starts.split(" ") : []).map((t, i) => [i + 1, `${t} ms`]) },
      { type: "notes", title: "Not measured here", items: ["Network: API payloads and requests per screen are checked with the api part (code and backend), not on the device.", "iOS: measure with Xcode Instruments (Time Profiler, Animation Hitches) on a release build."] },
    ].filter((s) => (s.rows || s.items).length),
  };
  if (warns.length) data.sections.unshift({ type: "notes", title: "Warnings", items: warns });
  fs.writeFileSync(reportPath, JSON.stringify(data, null, 2));
}
EOF
