#!/usr/bin/env bash
# Shareable API documentation from the project's OpenAPI file: interactive page (send requests),
# Postman collection, and the data structures of every endpoint (what it takes, what it returns).
#
# Usage: bash api-docs.sh <openapi.json|openapi.yaml> --out DIR [--base-url URL] [--title TEXT] [--report FILE]
#                         [--project DIR] [--brand-color COLOR] [--logo FILE] [--font FAMILY] [--spec-url URL]
#
# Writes into DIR:
#   index.html                     interactive reference with a request client (Scalar, pinned
#                                  version) under a bar in the project's colours with exports
#                                  (Postman collection, Postman environment, OpenAPI): open it, or
#                                  serve it from the app (e.g. public/docs/api) like API Platform
#   artifact.html                  the same page as a body for a shared rich page (read-only there:
#                                  a shared page cannot call your API)
#   <name>.postman_environment.json baseUrl and an empty secret token, for Postman environments
#   <name>.postman_collection.json Postman v2.1 collection (also imported by Insomnia, Bruno, Hoppscotch):
#                                  one folder per tag, {{baseUrl}} and {{token}} variables, bodies
#                                  from the spec's examples or generated from its schemas
#   api-structures.md              per endpoint: parameters, request body fields and response fields
#                                  with type, required, default, allowed values, format, example
# The OpenAPI file comes from the project's own generator (references/documentation.md);
# nothing is invented here: every field, type and default is read from the spec.
# Colours: --brand-color (any CSS colour), else read from --project: CSS variables --primary /
# --color-primary / --brand, tailwind.config "primary", <meta name="theme-color">; else neutral.
# --logo embeds a local image; --font sets the font family; --spec-url makes the page load the live
# spec served by the app's generator (always in sync) instead of the embedded copy.
# No token or secret is ever written: {{token}} stays empty in the collection.
# Exit code: 0 written, 2 usage error or invalid spec.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

SPEC="" OUT="" BASE="" TITLE="" REPORT_OUT="" PROJECT="" BRAND="" LOGO="" FONT="" SPEC_URL="" NEXT=""
for arg in "$@"; do
  case "$NEXT" in
    out) OUT="$arg"; NEXT=""; continue ;;
    base) BASE="$arg"; NEXT=""; continue ;;
    title) TITLE="$arg"; NEXT=""; continue ;;
    report) REPORT_OUT="$arg"; NEXT=""; continue ;;
    project) PROJECT="$arg"; NEXT=""; continue ;;
    brand) BRAND="$arg"; NEXT=""; continue ;;
    logo) LOGO="$arg"; NEXT=""; continue ;;
    font) FONT="$arg"; NEXT=""; continue ;;
    specurl) SPEC_URL="$arg"; NEXT=""; continue ;;
  esac
  case "$arg" in
    -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --out) NEXT=out ;;
    --base-url) NEXT=base ;;
    --title) NEXT=title ;;
    --report) NEXT=report ;;
    --project) NEXT=project ;;
    --brand-color) NEXT=brand ;;
    --logo) NEXT=logo ;;
    --font) NEXT=font ;;
    --spec-url) NEXT=specurl ;;
    -*) sld_die "unknown option: $arg" ;;
    *) SPEC="$arg" ;;
  esac
done
[ -z "$NEXT" ] || sld_die "--$NEXT needs a value"
[ -f "$SPEC" ] || sld_die "OpenAPI file not found: ${SPEC:-<none>}"
[ -n "$OUT" ] || sld_die "--out DIR is required"
[ -z "$PROJECT" ] || [ -d "$PROJECT" ] || sld_die "project directory not found: $PROJECT"
[ -z "$LOGO" ] || [ -f "$LOGO" ] || sld_die "logo file not found: $LOGO"
sld_has_cmd node || sld_die "node is required"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT

case "$SPEC" in
  *.yaml|*.yml)
    # YAML through Python's yaml module when present (no download); otherwise ask for JSON.
    PY=""; for p in python3 /usr/bin/python3; do "$p" -c 'import yaml' 2>/dev/null && { PY="$p"; break; }; done
    [ -n "$PY" ] || sld_die "YAML spec: install PyYAML, or export the spec as JSON (most generators can)"
    "$PY" -c 'import json,sys,yaml; json.dump(yaml.safe_load(open(sys.argv[1])), open(sys.argv[2],"w"), default=str)' "$SPEC" "$TMPD/spec.json" ||
      sld_die "invalid YAML: $SPEC" ;;
  *) cp "$SPEC" "$TMPD/spec.json" ;;
esac
mkdir -p "$OUT"

node - "$TMPD/spec.json" "$OUT" "$BASE" "$TITLE" "$REPORT_OUT" "$PROJECT" "$BRAND" "$LOGO" "$FONT" "$SPEC_URL" "$SCRIPT_DIR/../templates/api-docs/page.html" <<'EOF'
const fs = require("fs"), path = require("path");
const [specPath, out, baseOpt, titleOpt, reportOut, projectDir, brandOpt, logoPath, fontOpt, specUrl, pageTpl] = process.argv.slice(2);
let spec;
try { spec = JSON.parse(fs.readFileSync(specPath, "utf8")); } catch (e) { console.error(`ERROR: invalid JSON spec: ${e.message}`); process.exit(2); }
if (!/^3\./.test(String(spec.openapi || ""))) { console.error(`ERROR: OpenAPI 3.x expected (found ${spec.openapi || spec.swagger || "none"}); convert Swagger 2.0 with the generator or swagger2openapi`); process.exit(2); }
const title = titleOpt || (spec.info && spec.info.title) || "API";
const baseUrl = baseOpt || (spec.servers && spec.servers[0] && spec.servers[0].url) || "http://localhost";
const METHODS = ["get", "post", "put", "patch", "delete", "head", "options"];

// Local $ref resolution (#/components/...), with a cycle guard.
const deref = (o, seen = new Set()) => {
  if (!o || typeof o !== "object" || !o.$ref) return o;
  if (seen.has(o.$ref) || !o.$ref.startsWith("#/")) return { description: `(${o.$ref})` };
  seen.add(o.$ref);
  const target = o.$ref.slice(2).split("/").reduce((x, k) => (x ? x[k.replace(/~1/g, "/").replace(/~0/g, "~")] : undefined), spec);
  return deref(target || {}, seen);
};
const merge = (s) => {
  s = deref(s) || {};
  if (!s.allOf) return s;
  const m = { ...s, properties: { ...(s.properties || {}) }, required: [...(s.required || [])] };
  delete m.allOf;
  for (const part of s.allOf) { const p = merge(part); Object.assign(m.properties, p.properties || {}); m.required.push(...(p.required || [])); if (!m.type && p.type) m.type = p.type; }
  return m;
};
const typeOf = (s) => {
  s = merge(s);
  if (s.oneOf || s.anyOf) return (s.oneOf || s.anyOf).map(typeOf).join(" | ");
  let t = Array.isArray(s.type) ? s.type.filter((x) => x !== "null").join(" | ") : s.type || (s.properties ? "object" : s.items ? "array" : "any");
  if (t === "array") t = `array<${typeOf(s.items || {})}>`;
  return t;
};
const nullable = (s) => Boolean(s.nullable || (Array.isArray(s.type) && s.type.includes("null")));

// Flatten a schema into rows: dotted path (items[].id), type, required, default, allowed values…
const flatten = (schema, prefix = "", required = true, rows = [], depth = 0, seen = new Set()) => {
  const s = merge(schema);
  if (depth > 6) return rows;
  const props = s.properties || {};
  const req = new Set(s.required || []);
  for (const [name, raw] of Object.entries(props)) {
    const p = merge(raw), key = prefix ? `${prefix}.${name}` : name;
    rows.push({ field: key, type: typeOf(p), required: required && req.has(name), nullable: nullable(p), default: p.default, enum: p.enum,
      format: p.format, min: p.minimum ?? p.minLength ?? p.minItems, max: p.maximum ?? p.maxLength ?? p.maxItems, example: p.example, description: p.description });
    const ref = raw && raw.$ref;
    if (ref && seen.has(ref)) continue;
    const next = new Set(seen); if (ref) next.add(ref);
    if (p.properties || p.allOf) flatten(p, key, required && req.has(name), rows, depth + 1, next);
    const items = p.items && merge(p.items);
    if (items && (items.properties || items.allOf)) flatten(items, `${key}[]`, required && req.has(name), rows, depth + 1, next);
  }
  if (!prefix && !Object.keys(props).length && s.items) {
    const items = merge(s.items);
    if (items.properties || items.allOf) flatten(items, "[]", true, rows, depth + 1, seen);
  }
  return rows;
};
// Example value: the spec's example or default first, then its allowed values, then the type.
const sample = (schema, depth = 0) => {
  const s = merge(schema);
  if (s.example !== undefined) return s.example;
  if (s.default !== undefined) return s.default;
  if (s.enum) return s.enum[0];
  if (depth > 5) return null;
  if (s.oneOf || s.anyOf) return sample((s.oneOf || s.anyOf)[0], depth + 1);
  const t = Array.isArray(s.type) ? s.type.find((x) => x !== "null") : s.type;
  if (t === "object" || s.properties) return Object.fromEntries(Object.entries(s.properties || {}).map(([k, v]) => [k, sample(v, depth + 1)]));
  if (t === "array") return [sample(s.items || {}, depth + 1)];
  if (t === "integer" || t === "number") return s.minimum ?? 0;
  if (t === "boolean") return false;
  if (s.format === "date-time") return "2026-01-01T00:00:00Z";
  if (s.format === "date") return "2026-01-01";
  if (s.format === "email") return "user@example.com";
  return "string";
};
const mediaOf = (content) => { const c = content || {}; const k = c["application/json"] ? "application/json" : Object.keys(c)[0]; return k ? { type: k, ...c[k] } : null; };

// Endpoints.
const endpoints = [];
for (const [p, item] of Object.entries(spec.paths || {})) {
  for (const m of METHODS) {
    if (!item[m]) continue;
    const op = item[m];
    const params = [...(item.parameters || []), ...(op.parameters || [])].map(deref);
    const body = op.requestBody && deref(op.requestBody);
    const media = body && mediaOf(body.content);
    const responses = Object.entries(op.responses || {}).map(([code, r]) => { r = deref(r); const md = mediaOf(r.content); return { code, description: r.description || "", media: md }; });
    const security = op.security ?? spec.security ?? [];
    endpoints.push({ method: m.toUpperCase(), path: p, op, tag: (op.tags && op.tags[0]) || "default", params, body, media, responses, secured: security.length > 0 });
  }
}
if (!endpoints.length) { console.error("ERROR: the spec has no paths"); process.exit(2); }

// Postman collection v2.1.
const schemes = (spec.components && spec.components.securitySchemes) || {};
const bearer = Object.values(schemes).map(deref).some((s) => s.type === "http" && /bearer/i.test(s.scheme || "")) || Object.values(schemes).map(deref).some((s) => s.type === "oauth2" || s.type === "openIdConnect");
const apiKey = Object.values(schemes).map(deref).find((s) => s.type === "apiKey");
const folders = {};
for (const e of endpoints) {
  const segs = e.path.replace(/^\//, "").split("/").map((x) => x.replace(/^\{(.+)\}$/, ":$1"));
  const query = e.params.filter((x) => x.in === "query").map((x) => ({ key: x.name, value: String(sample(x.schema || {}) ?? ""), description: x.description || "", disabled: !x.required }));
  const variable = e.params.filter((x) => x.in === "path").map((x) => ({ key: x.name, value: String(sample(x.schema || {}) ?? ""), description: x.description || "" }));
  const header = [{ key: "Accept", value: "application/json" }, ...e.params.filter((x) => x.in === "header").map((x) => ({ key: x.name, value: String(sample(x.schema || {}) ?? "") }))];
  const request = { method: e.method, header, url: { raw: `{{baseUrl}}/${segs.join("/")}${query.length ? "?" + query.filter((q) => !q.disabled).map((q) => `${q.key}=${q.value}`).join("&") : ""}`, host: ["{{baseUrl}}"], path: segs, query, variable }, description: [e.op.summary, e.op.description].filter(Boolean).join("\n\n") };
  if (e.media) {
    const ex = e.media.example ?? (e.media.examples && deref(Object.values(e.media.examples)[0]).value) ?? sample(e.media.schema || {});
    if (/json/.test(e.media.type)) { header.push({ key: "Content-Type", value: e.media.type }); request.body = { mode: "raw", raw: JSON.stringify(ex, null, 2), options: { raw: { language: "json" } } }; }
    else if (/form/.test(e.media.type)) request.body = { mode: /multipart/.test(e.media.type) ? "formdata" : "urlencoded", [/multipart/.test(e.media.type) ? "formdata" : "urlencoded"]: Object.entries(ex && typeof ex === "object" ? ex : {}).map(([k, v]) => ({ key: k, value: typeof v === "object" ? JSON.stringify(v) : String(v) })) };
  }
  if (!e.secured) request.auth = { type: "noauth" };
  (folders[e.tag] ||= []).push({ name: e.op.summary || `${e.method} ${e.path}`, request });
}
const collection = {
  info: { name: title, description: (spec.info && spec.info.description) || "", schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json" },
  variable: [{ key: "baseUrl", value: baseUrl }, { key: "token", value: "", description: "Fill it in your own environment; never commit it." }],
  ...(bearer ? { auth: { type: "bearer", bearer: [{ key: "token", value: "{{token}}", type: "string" }] } } : apiKey ? { auth: { type: "apikey", apikey: [{ key: "key", value: apiKey.name, type: "string" }, { key: "value", value: "{{token}}", type: "string" }, { key: "in", value: apiKey.in === "query" ? "query" : "header", type: "string" }] } } : {}),
  item: Object.entries(folders).map(([name, item]) => ({ name, item })),
};
const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "api";
fs.writeFileSync(path.join(out, `${slug}.postman_collection.json`), JSON.stringify(collection, null, 2) + "\n");

// Data structures, per endpoint.
const cell = (v) => (v === undefined || v === null || v === "" ? "" : String(Array.isArray(v) ? v.join(", ") : typeof v === "object" ? JSON.stringify(v) : v).replace(/\|/g, "\\|").replace(/\n/g, " "));
const table = (rows) => rows.length ? ["| Field | Type | Required | Default | Allowed values | Format / limits | Example | Description |", "|---|---|---|---|---|---|---|---|",
  ...rows.map((r) => `| \`${cell(r.field)}\` | ${cell(r.type)}${r.nullable ? " \\| null" : ""} | ${r.required ? "yes" : "no"} | ${cell(r.default)} | ${cell(r.enum)} | ${cell([r.format, r.min != null ? `min ${r.min}` : "", r.max != null ? `max ${r.max}` : ""].filter(Boolean).join(", "))} | ${cell(r.example)} | ${cell(r.description)} |`)] : ["No fields described in the spec."];
const md = [`# ${title} – data structures`, "", `Read from the OpenAPI file (${(spec.info && spec.info.version) || "no version"}): ${endpoints.length} endpoints. Base URL: \`${baseUrl}\`. Regenerate after each API change.`, ""];
const noResponseSchema = [], noDescription = [];
for (const [tag, list] of Object.entries(endpoints.reduce((a, e) => ((a[e.tag] ||= []).push(e), a), {}))) {
  md.push(`## ${tag}`, "");
  for (const e of list) {
    md.push(`### \`${e.method} ${e.path}\`${e.op.summary ? ` – ${e.op.summary}` : ""}`, "");
    if (e.op.description) md.push(e.op.description, "");
    md.push(`Auth: ${e.secured ? "required" : "none"}${e.op.deprecated ? " · **deprecated**" : ""}`, "");
    if (e.params.length) {
      md.push("**Parameters**", "", "| In | Name | Type | Required | Default | Allowed values | Description |", "|---|---|---|---|---|---|---|");
      for (const x of e.params) { const sc = merge(x.schema || {}); md.push(`| ${x.in} | \`${cell(x.name)}\` | ${cell(typeOf(sc))} | ${x.required ? "yes" : "no"} | ${cell(sc.default)} | ${cell(sc.enum)} | ${cell(x.description)} |`); }
      md.push("");
    }
    if (e.media) md.push(`**Request body** (\`${e.media.type}\`${e.body.required ? ", required" : ""})`, "", ...table(flatten(e.media.schema || {})), "");
    for (const r of e.responses) {
      md.push(`**Response ${r.code}**${r.description ? ` – ${r.description}` : ""}`, "");
      if (r.media && r.media.schema) md.push(...table(flatten(r.media.schema)), "");
      else if (/^2/.test(r.code) && r.code !== "204") { md.push("No response schema in the spec: the front cannot know what this returns.", ""); noResponseSchema.push(`${e.method} ${e.path}`); }
    }
    if (!e.op.summary && !e.op.description) noDescription.push(`${e.method} ${e.path}`);
  }
}
fs.writeFileSync(path.join(out, "api-structures.md"), md.join("\n") + "\n");

// Brand colour: given, or read from the project's own tokens; never invented.
const COLOR_RE = /^(#[0-9a-f]{3,8}|(rgb|rgba|hsl|hsla|oklch|oklab|lab|lch)\([0-9.,%\s/+-]+\))$/i;
let brand = null, brandFrom = "neutral default (no brand colour found)";
if (brandOpt) { if (!COLOR_RE.test(brandOpt.trim())) { console.error(`ERROR: --brand-color must be a CSS colour (hex, rgb(), hsl(), oklch()…): ${brandOpt}`); process.exit(2); } brand = brandOpt.trim(); brandFrom = "--brand-color"; }
else if (projectDir) {
  const SKIP = new Set(["node_modules", "vendor", ".git", "dist", "build", ".next", "storage", "coverage", "public"]);
  const files = [];
  (function walk(dir, depth) {
    if (depth > 5 || files.length > 600) return;
    let entries; try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      const f = path.join(dir, e.name);
      if (e.isDirectory()) { if (!SKIP.has(e.name) && !e.name.startsWith(".")) walk(f, depth + 1); }
      else if (/\.(css|scss|sass|less)$|^tailwind\.config\.(js|cjs|mjs|ts)$|^index\.html$|\.blade\.php$/.test(e.name)) files.push(f);
    }
  })(projectDir, 0);
  const color = "(#[0-9a-fA-F]{3,8}|(?:rgb|rgba|hsl|hsla|oklch|oklab)\\([0-9.,%\\s/+-]+\\))";
  const rules = [
    ["CSS variable", new RegExp(`--(?:color-)?(?:primary|brand)(?:-color)?(?:-(?:500|600|default))?\\s*:\\s*${color}`, "i")],
    ["tailwind.config primary", new RegExp(`primary\\s*:\\s*(?:\\{[^}]*?(?:DEFAULT|500|600)\\s*:\\s*)?['"]${color}['"]`)],
    ["theme-color meta", new RegExp(`name=["']theme-color["'][^>]*content=["']${color}["']`, "i")],
  ];
  outer: for (const [label, re] of rules) for (const f of files) {
    let text; try { const st = fs.statSync(f); if (st.size > 600000) continue; text = fs.readFileSync(f, "utf8"); } catch { continue; }
    const m = text.match(re);
    if (m && COLOR_RE.test(m[1])) { brand = m[1]; brandFrom = `${label} in ${path.relative(projectDir, f)}`; break outer; }
  }
}
const accent = brand || "#3d5a80";
const hex = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(accent) ? accent : null;
const onBrand = (() => { if (!hex) return "#ffffff"; let h = hex.slice(1); if (h.length === 3) h = h.replace(/./g, "$&$&");
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16) / 255).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4 ? "#111111" : "#ffffff"; })();
const brandDark = `color-mix(in oklab, ${accent} 62%, white)`;
if (fontOpt && !/^[\w\s,"'-]+$/.test(fontOpt)) { console.error("ERROR: --font must be a font-family list"); process.exit(2); }
const font = fontOpt || `system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`;
let logo = "";
if (logoPath) {
  const ext = path.extname(logoPath).slice(1).toLowerCase(), mime = { svg: "image/svg+xml", png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp" }[ext];
  if (!mime) { console.error("ERROR: --logo must be svg, png, jpg or webp"); process.exit(2); }
  const data = fs.readFileSync(logoPath); if (data.length > 300000) { console.error("ERROR: --logo is larger than 300 KB"); process.exit(2); }
  logo = `<img alt="" src="data:${mime};base64,${data.toString("base64")}">`;
}
if (specUrl && !/^(https?:\/\/|\/)[^\s"'<>]*$/.test(specUrl)) { console.error("ERROR: --spec-url must be an http(s) URL or a path"); process.exit(2); }
const environment = { name: `${title} (local)`, values: [{ key: "baseUrl", value: baseUrl, type: "default", enabled: true }, { key: "token", value: "", type: "secret", enabled: true }], _postman_variable_scope: "environment" };
fs.writeFileSync(path.join(out, `${slug}.postman_environment.json`), JSON.stringify(environment, null, 2) + "\n");
fs.writeFileSync(path.join(out, "openapi.json"), JSON.stringify(spec, null, 2) + "\n");

// Page: branded bar + Scalar reference; everything embedded as JSON text ("<" escaped).
const css = `.light-mode{--scalar-color-accent:${accent};--scalar-font:${font}}.dark-mode{--scalar-color-accent:${brandDark};--scalar-font:${font}}`;
const esc = (x) => String(x).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const page = (shared) => {
  const data = { title, version: spec.info && spec.info.version, baseUrl, slug, spec, collection, environment, css, specUrl: shared ? null : specUrl || null, shared };
  const json = JSON.stringify(data).replace(/</g, "\\u003c").replace(/\u2028/g, "\\u2028").replace(/\u2029/g, "\\u2029");
  return fs.readFileSync(pageTpl, "utf8").replace("__SISKA_TITLE__", () => esc(title)).replace("__SISKA_BRAND__", () => accent).replace("__SISKA_BRAND_DARK__", () => brandDark)
    .replace("__SISKA_ON_BRAND__", () => onBrand).replace("__SISKA_FONT__", () => font).replace("__SISKA_LOGO__", () => logo).replace("__SISKA_DATA__", () => json);
};
fs.writeFileSync(path.join(out, "index.html"), `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n</head>\n<body>\n${page(false)}\n</body>\n</html>\n`);
fs.writeFileSync(path.join(out, "artifact.html"), page(true));

if (reportOut) {
  fs.writeFileSync(reportOut, JSON.stringify({
    command: "api-docs", title: `API · ${title}`, date: new Date().toISOString().slice(0, 16).replace("T", " "), target: baseUrl,
    verdict: { status: noResponseSchema.length ? "warn" : "ok", summary: `${endpoints.length} endpoints in ${Object.keys(folders).length} groups; interactive page, Postman collection and data structures written.` },
    metrics: [
      { label: "Endpoints", value: endpoints.length, status: "info" }, { label: "Groups", value: Object.keys(folders).length, status: "info" },
      { label: "Secured", value: endpoints.filter((e) => e.secured).length, status: "info" },
      { label: "No response schema", value: noResponseSchema.length, status: noResponseSchema.length ? "warn" : "ok" },
      { label: "No description", value: noDescription.length, status: noDescription.length ? "warn" : "ok" },
    ],
    sections: [
      { type: "table", title: "Endpoints", columns: ["Method", "Path", "Group", "Auth", "Request body", "Responses"],
        rows: endpoints.map((e) => [e.method, e.path, e.tag, e.secured ? "yes" : "no", e.media ? e.media.type : "–", e.responses.map((r) => r.code).join(", ")]) },
      ...(noResponseSchema.length ? [{ type: "notes", title: "Endpoints without a response schema", items: noResponseSchema }] : []),
    ],
  }, null, 2));
}
console.log(`## API docs: ${title}`);
console.log(`${endpoints.length} endpoints · ${Object.keys(folders).length} groups · base URL ${baseUrl}`);
for (const e of noResponseSchema) console.log(`WARN:  no response schema: ${e}`);
console.log(`colours: ${accent} – ${brandFrom}`);
console.log(`written: ${path.join(out, "index.html")} (interactive, send requests, exports${specUrl ? `, live spec from ${specUrl}` : ""})`);
console.log(`written: ${path.join(out, `${slug}.postman_environment.json`)} and openapi.json`);
console.log(`written: ${path.join(out, `${slug}.postman_collection.json`)} (Postman, Insomnia, Bruno)`);
console.log(`written: ${path.join(out, "api-structures.md")} (fields sent and returned)`);
console.log(`written: ${path.join(out, "artifact.html")} (shared read-only page)`);
EOF
