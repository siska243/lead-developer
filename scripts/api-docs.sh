#!/usr/bin/env bash
# Shareable API documentation from the project's OpenAPI file: interactive page (send requests),
# Postman collection, and the data structures of every endpoint (what it takes, what it returns).
#
# Usage: bash api-docs.sh <openapi.json|openapi.yaml> --out DIR [--base-url URL] [--title TEXT] [--report FILE]
#
# Writes into DIR:
#   index.html                     interactive reference with a request client (Scalar, pinned
#                                  version): open it in a browser to read and "Test Request"
#   artifact.html                  the same page as a body for a shared rich page (read-only there:
#                                  a shared page cannot call your API)
#   <name>.postman_collection.json Postman v2.1 collection (also imported by Insomnia and Bruno):
#                                  one folder per tag, {{baseUrl}} and {{token}} variables, bodies
#                                  from the spec's examples or generated from its schemas
#   api-structures.md              per endpoint: parameters, request body fields and response fields
#                                  with type, required, default, allowed values, format, example
# The OpenAPI file comes from the project's own generator (references/documentation.md);
# nothing is invented here: every field, type and default is read from the spec.
# No token or secret is ever written: {{token}} stays empty in the collection.
# Exit code: 0 written, 2 usage error or invalid spec.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

SPEC="" OUT="" BASE="" TITLE="" REPORT_OUT="" NEXT=""
for arg in "$@"; do
  case "$NEXT" in
    out) OUT="$arg"; NEXT=""; continue ;;
    base) BASE="$arg"; NEXT=""; continue ;;
    title) TITLE="$arg"; NEXT=""; continue ;;
    report) REPORT_OUT="$arg"; NEXT=""; continue ;;
  esac
  case "$arg" in
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --out) NEXT=out ;;
    --base-url) NEXT=base ;;
    --title) NEXT=title ;;
    --report) NEXT=report ;;
    -*) sld_die "unknown option: $arg" ;;
    *) SPEC="$arg" ;;
  esac
done
[ -z "$NEXT" ] || sld_die "--$NEXT needs a value"
[ -f "$SPEC" ] || sld_die "OpenAPI file not found: ${SPEC:-<none>}"
[ -n "$OUT" ] || sld_die "--out DIR is required"
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

node - "$TMPD/spec.json" "$OUT" "$BASE" "$TITLE" "$REPORT_OUT" <<'EOF'
const fs = require("fs"), path = require("path");
const [specPath, out, baseOpt, titleOpt, reportOut] = process.argv.slice(2);
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

// Interactive reference (Scalar, pinned); the spec is embedded as JSON text, "<" escaped.
const json = JSON.stringify(spec).replace(/</g, "\\u003c");
const esc = (x) => String(x).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const body = (note) => `<title>${esc(title)}</title>
${note}<div id="app"></div>
<script id="siska-spec" type="application/json">${json}</script>
<script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.72.3/dist/browser/standalone.js"></script>
<script>
  // No proxy: requests go straight from the browser to the API (the API must allow its origin, CORS).
  Scalar.createApiReference("#app", { content: JSON.parse(document.getElementById("siska-spec").textContent), servers: [{ url: ${JSON.stringify(baseUrl)} }], withDefaultFonts: false });
</script>
`;
fs.writeFileSync(path.join(out, "index.html"), `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n</head>\n<body>\n${body("")}</body>\n</html>\n`);
fs.writeFileSync(path.join(out, "artifact.html"), body(`<p style="margin:0;padding:10px 16px;font:14px system-ui,sans-serif;background:#fbf0d9;color:#6b4a00">Shared reference: read the endpoints and their data. To send requests, open <code>index.html</code> locally or import the Postman collection.</p>\n`));

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
console.log(`written: ${path.join(out, "index.html")} (interactive, send requests)`);
console.log(`written: ${path.join(out, `${slug}.postman_collection.json`)} (Postman, Insomnia, Bruno)`);
console.log(`written: ${path.join(out, "api-structures.md")} (fields sent and returned)`);
console.log(`written: ${path.join(out, "artifact.html")} (shared read-only page)`);
EOF
