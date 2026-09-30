#!/usr/bin/env bash
# Document the real data model: tables, columns, keys, indexes and relations, with an ER diagram.
#
# Usage: bash data-model.sh [PROJECT_DIR] [--sqlite FILE | --from-json FILE] [--only REGEX]
#                           [--json OUT] [--markdown OUT] [--report OUT]
#
# Source of the schema, never guessed:
#   Laravel (artisan found)  the framework's own read-only introspection (Schema::getTables,
#                            getColumns, getIndexes, getForeignKeys) on the configured connection;
#   --sqlite FILE            PRAGMA introspection of a SQLite file (read-only);
#   --from-json FILE         a schema already in the normalized format (other stacks: Prisma,
#                            Django, TypeORM… exported by the agent from the project's own tools).
# Outputs: --json the normalized schema, --markdown docs page (Mermaid ER diagram + table
# dictionary), --report visual report data. Checks: tables without a primary key, foreign keys
# without an index (slow joins and deletes).
# Only the schema is read, never rows. Credentials stay in the project's config and are never printed.
# Exit code: 0 documented, 1 introspection failed, 2 usage error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

ROOT_ARG="." SQLITE="" FROM="" ONLY="" JSON_OUT="" MD_OUT="" REPORT_OUT="" NEXT=""
for arg in "$@"; do
  case "$NEXT" in
    sqlite) SQLITE="$arg"; NEXT=""; continue ;;
    from) FROM="$arg"; NEXT=""; continue ;;
    only) ONLY="$arg"; NEXT=""; continue ;;
    json) JSON_OUT="$arg"; NEXT=""; continue ;;
    md) MD_OUT="$arg"; NEXT=""; continue ;;
    report) REPORT_OUT="$arg"; NEXT=""; continue ;;
  esac
  case "$arg" in
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --sqlite) NEXT=sqlite ;;
    --from-json) NEXT=from ;;
    --only) NEXT=only ;;
    --json) NEXT=json ;;
    --markdown) NEXT=md ;;
    --report) NEXT=report ;;
    -*) sld_die "unknown option: $arg" ;;
    *) ROOT_ARG="$arg" ;;
  esac
done
[ -z "$NEXT" ] || sld_die "--$NEXT needs a value"
sld_has_cmd node || sld_die "node is required"
ROOT="$(sld_project_root "$ROOT_ARG")"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
RAW="$TMPD/raw.json"

if [ -n "$FROM" ]; then
  [ -f "$FROM" ] || sld_die "schema file not found: $FROM"
  cp "$FROM" "$RAW"; SOURCE="file $(basename "$FROM")"
elif [ -n "$SQLITE" ]; then
  [ -f "$SQLITE" ] || sld_die "SQLite file not found: $SQLITE"
  PY="$(command -v python3 || true)"; [ -n "$PY" ] || sld_die "python3 is required for --sqlite"
  "$PY" - "$SQLITE" >"$RAW" <<'PY' || { sld_info "ERROR: SQLite introspection failed"; exit 1; }
import json, sqlite3, sys
db = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
q = lambda sql, *a: db.execute(sql, a).fetchall()
tables = []
for (name,) in q("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"):
    cols = q(f'PRAGMA table_info("{name}")')
    idx = []
    for _, iname, unique, origin, _p in q(f'PRAGMA index_list("{name}")'):
        idx.append({"name": iname, "columns": [r[2] for r in q(f'PRAGMA index_info("{iname}")')], "unique": bool(unique), "primary": origin == "pk"})
    pk = [c[1] for c in sorted(cols, key=lambda c: c[5]) if c[5]]
    if pk: idx.append({"name": "primary", "columns": pk, "unique": True, "primary": True})
    fks = {}
    for fid, _seq, ftable, frm, to, _upd, on_delete, _m in q(f'PRAGMA foreign_key_list("{name}")'):
        fk = fks.setdefault(fid, {"columns": [], "foreign_table": ftable, "foreign_columns": [], "on_delete": on_delete})
        fk["columns"].append(frm); fk["foreign_columns"].append(to)
    tables.append({"name": name,
        "columns": [{"name": c[1], "type": c[2] or "", "nullable": not c[3] and not c[5], "default": c[4]} for c in cols],
        "indexes": idx, "foreign_keys": list(fks.values())})
print(json.dumps({"driver": "sqlite", "database": sys.argv[1].split("/")[-1], "tables": tables}))
PY
  SOURCE="SQLite $(basename "$SQLITE")"
elif [ -f "$ROOT/artisan" ]; then
  sld_has_cmd php || sld_die "php is required for a Laravel project"
  cat >"$TMPD/introspect.php" <<'PHP'
<?php
// Read-only schema introspection through the application's own configuration.
require $argv[1] . '/vendor/autoload.php';
$app = require $argv[1] . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$schema = Illuminate\Support\Facades\Schema::connection(null);
$db = Illuminate\Support\Facades\DB::connection();
$tables = [];
foreach ($schema->getTables() as $t) {
    $name = $t['name'];
    $tables[] = [
        'name' => $name, 'comment' => $t['comment'] ?? null,
        'columns' => array_map(fn ($c) => ['name' => $c['name'], 'type' => $c['type'], 'nullable' => $c['nullable'],
            'default' => $c['default'], 'auto_increment' => $c['auto_increment'] ?? false, 'comment' => $c['comment'] ?? null], $schema->getColumns($name)),
        'indexes' => array_map(fn ($i) => ['name' => $i['name'], 'columns' => $i['columns'], 'unique' => $i['unique'], 'primary' => $i['primary']], $schema->getIndexes($name)),
        'foreign_keys' => array_map(fn ($f) => ['columns' => $f['columns'], 'foreign_table' => $f['foreign_table'],
            'foreign_columns' => $f['foreign_columns'], 'on_delete' => $f['on_delete'] ?? null], $schema->getForeignKeys($name)),
    ];
}
echo "__SISKA_SCHEMA__" . json_encode(['driver' => $db->getDriverName(), 'database' => $db->getDatabaseName(), 'tables' => $tables]) . "\n";
PHP
  out="$(sld_spin "Reading the database schema (read-only)" php "$TMPD/introspect.php" "$ROOT" 2>"$TMPD/php.err")" || {
    sld_info "ERROR: Laravel schema introspection failed (database reachable? Laravel 11+ needed for Schema::getTables):"; tail -n 5 "$TMPD/php.err"; exit 1; }
  printf '%s\n' "$out" | sed -n 's/^__SISKA_SCHEMA__//p' >"$RAW"
  [ -s "$RAW" ] || { sld_info "ERROR: no schema returned by the application"; exit 1; }
  SOURCE="Laravel schema introspection"
else
  sld_die "no schema source: Laravel project not found; use --sqlite FILE or --from-json FILE"
fi

node - "$RAW" "$ONLY" "$JSON_OUT" "$MD_OUT" "$REPORT_OUT" "$SOURCE" <<'EOF'
const fs = require("fs");
const [raw, only, jsonOut, mdOut, reportOut, source] = process.argv.slice(2);
let s;
try { s = JSON.parse(fs.readFileSync(raw, "utf8")); } catch (e) { console.error(`ERROR: invalid schema JSON: ${e.message}`); process.exit(2); }
if (!Array.isArray(s.tables)) { console.error('ERROR: schema JSON needs "tables": [...]'); process.exit(2); }
const re = only ? new RegExp(only) : null;
const tables = s.tables.filter((t) => !re || re.test(t.name)).sort((a, b) => a.name.localeCompare(b.name));
const names = new Set(tables.map((t) => t.name));
const pkOf = (t) => ((t.indexes || []).find((i) => i.primary) || {}).columns || [];

// Checks worth fixing: no primary key; foreign key columns not leading any index.
const noPk = tables.filter((t) => !pkOf(t).length).map((t) => t.name);
const fkNoIndex = [];
for (const t of tables) for (const fk of t.foreign_keys || []) {
  const covered = (t.indexes || []).some((i) => fk.columns.every((c, n) => i.columns[n] === c));
  if (!covered) fkNoIndex.push(`${t.name}.${fk.columns.join(",")} → ${fk.foreign_table}`);
}
const fkCount = tables.reduce((n, t) => n + (t.foreign_keys || []).length, 0);
const colCount = tables.reduce((n, t) => n + t.columns.length, 0);

// Mermaid ER diagram; compact (keys only) when the schema is large.
const id = (x) => String(x).replace(/[^A-Za-z0-9_]/g, "_");
const typ = (x) => String(x || "unknown").replace(/\(.*$/, "").replace(/[^A-Za-z0-9_]/g, "_") || "unknown";
const compact = tables.length > 25;
const lines = ["erDiagram"];
for (const t of tables) {
  const pk = new Set(pkOf(t)), fkCols = new Set((t.foreign_keys || []).flatMap((f) => f.columns));
  const cols = t.columns.filter((c) => !compact || pk.has(c.name) || fkCols.has(c.name));
  lines.push(`  ${id(t.name)} {`);
  for (const c of cols) lines.push(`    ${typ(c.type)} ${id(c.name)}${pk.has(c.name) ? " PK" : fkCols.has(c.name) ? " FK" : ""}`);
  lines.push("  }");
}
for (const t of tables) for (const fk of t.foreign_keys || []) {
  if (!names.has(fk.foreign_table)) continue;
  const nullable = fk.columns.some((c) => (t.columns.find((x) => x.name === c) || {}).nullable);
  lines.push(`  ${id(fk.foreign_table)} ${nullable ? "|o" : "||"}--o{ ${id(t.name)} : "${fk.columns.join(", ")}"`);
}
const mermaid = lines.join("\n");

const norm = { driver: s.driver || null, database: s.database || null, source, generated_at: new Date().toISOString(), tables };
if (jsonOut) fs.writeFileSync(jsonOut, JSON.stringify(norm, null, 2) + "\n");

if (mdOut) {
  const esc = (v) => (v == null ? "" : String(v).replace(/\|/g, "\\|").replace(/\n/g, " "));
  const md = [`# Data model`, "", `Generated from ${source}${s.driver ? ` (${s.driver})` : ""} on ${norm.generated_at.slice(0, 10)}. ${tables.length} tables, ${colCount} columns, ${fkCount} foreign keys. Regenerate it after each migration.`, ""];
  md.push("## Diagram", "");
  if (compact) md.push("Large schema: the diagram shows keys only; the dictionary below has every column. Use `--only` to draw one domain.", "");
  md.push("```mermaid", mermaid, "```", "");
  if (noPk.length || fkNoIndex.length) {
    md.push("## Checks", "");
    for (const n of noPk) md.push(`- \`${n}\` has no primary key.`);
    for (const f of fkNoIndex) md.push(`- Foreign key \`${f}\` has no index (slow joins and cascades).`);
    md.push("");
  }
  md.push("## Tables", "");
  for (const t of tables) {
    const pk = new Set(pkOf(t));
    md.push(`### ${t.name}`, "");
    if (t.comment) md.push(esc(t.comment), "");
    md.push("| Column | Type | Null | Default | Key | Comment |", "|---|---|---|---|---|---|");
    for (const c of t.columns) {
      const fk = (t.foreign_keys || []).find((f) => f.columns.includes(c.name));
      md.push(`| ${esc(c.name)} | ${esc(c.type)} | ${c.nullable ? "yes" : "no"} | ${esc(c.default)} | ${pk.has(c.name) ? "PK" : ""}${fk ? `FK → ${esc(fk.foreign_table)}` : ""} | ${esc(c.comment)} |`);
    }
    const idx = (t.indexes || []).filter((i) => !i.primary);
    if (idx.length) md.push("", "Indexes: " + idx.map((i) => `\`${i.name}\` (${i.columns.join(", ")}${i.unique ? ", unique" : ""})`).join(" · "));
    const refs = tables.flatMap((o) => (o.foreign_keys || []).filter((f) => f.foreign_table === t.name).map((f) => `${o.name}.${f.columns.join(",")}`));
    if (refs.length) md.push("", "Referenced by: " + refs.map((r) => `\`${r}\``).join(" · "));
    md.push("");
  }
  fs.writeFileSync(mdOut, md.join("\n"));
}

if (reportOut) {
  const findings = [
    ...noPk.map((n) => ({ severity: "medium", title: `No primary key on ${n}`, where: n, fix: "Add a primary key (updates and replication need one)." })),
    ...fkNoIndex.map((f) => ({ severity: "medium", title: `Foreign key without index: ${f}`, where: f.split(" ")[0], impact: "Slow joins, slow deletes and cascades on large tables", fix: "Add an index on the foreign key column(s) in a migration." })),
  ];
  const data = {
    command: "data-model", title: `Data model${s.database ? ` · ${s.database}` : ""}`, date: norm.generated_at.slice(0, 16).replace("T", " "),
    verdict: { status: findings.length ? "warn" : "ok", summary: `${tables.length} tables, ${colCount} columns, ${fkCount} foreign keys, read from ${source}.` },
    metrics: [
      { label: "Tables", value: tables.length, status: "info" }, { label: "Columns", value: colCount, status: "info" },
      { label: "Foreign keys", value: fkCount, status: "info" },
      { label: "Without PK", value: noPk.length, status: noPk.length ? "warn" : "ok" },
      { label: "FK without index", value: fkNoIndex.length, status: fkNoIndex.length ? "warn" : "ok" },
    ],
    sections: [
      tables.length <= 60
        ? { type: "diagram", title: compact ? "Diagram (keys only)" : "Diagram", code: mermaid }
        : { type: "notes", title: "Diagram", items: [`${tables.length} tables: too many for one readable diagram. Draw one domain at a time with --only (e.g. --only 'order|client').`] },
      ...(findings.length ? [{ type: "findings", title: "Checks", items: findings }] : []),
      { type: "table", title: "Tables", columns: ["Table", "Columns", "Primary key", "Foreign keys", "Referenced by"],
        rows: tables.map((t) => [t.name, t.columns.length, pkOf(t).join(", ") || "–", (t.foreign_keys || []).map((f) => f.foreign_table).join(", ") || "–",
          tables.filter((o) => (o.foreign_keys || []).some((f) => f.foreign_table === t.name)).map((o) => o.name).join(", ") || "–"]) },
    ],
  };
  fs.writeFileSync(reportOut, JSON.stringify(data, null, 2));
}
console.log(`## Data model (${source})`);
console.log(`${tables.length} tables · ${colCount} columns · ${fkCount} foreign keys${re ? ` (filter: ${only})` : ""}`);
for (const n of noPk) console.log(`WARN:  no primary key: ${n}`);
for (const f of fkNoIndex) console.log(`WARN:  foreign key without index: ${f}`);
if (mdOut) console.log(`written: ${mdOut}`);
EOF
