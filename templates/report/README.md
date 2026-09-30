# Visual report

Every command result (audits, check-code, optimize, document) is also delivered as one page built from
`report.html` by `scripts/report.sh`. The agent writes only the JSON below; layout, themes (light/dark),
phone width and escaping come from the template, so every report looks the same in every agent.

```bash
bash scripts/report.sh data.json --out report.html                 # page body, to publish as a rich page
bash scripts/report.sh data.json --out .siska/reports/x.html --standalone   # file to open in a browser
```

## Data
```json
{
  "command": "optimize",
  "title": "Orders page",
  "project": "rubix-front", "branch": "perf/orders", "date": "2026-09-30 17:40",
  "target": "http://localhost:4173/order-v2",
  "lang": "fr",
  "verdict": { "status": "warn", "label": "Needs attention", "summary": "3 fixes applied, 1 waiting for your yes." },
  "metrics": [
    { "label": "Score", "value": 78, "unit": "/100", "before": 42, "status": "warn" },
    { "label": "LCP", "value": 2.1, "unit": "s", "before": 5.1, "status": "ok" }
  ],
  "sections": [
    { "type": "table", "title": "API payloads", "columns": ["Route", "Unused fields", "Payload"],
      "rows": [["GET /api/orders", "customer.address, items.*.meta", "300 KB → 42 KB"], ["GET /api/me", { "text": "ok", "status": "ok" }, "2 KB"]] },
    { "type": "findings", "title": "Findings", "items": [
      { "severity": "high", "title": "Orders list fetched twice on load", "where": "src/pages/OrderV2.tsx:48",
        "impact": "+300 KB, +1 request", "fix": "Share the query key with the filters bar", "state": "applied (a1b2c3d)" } ] },
    { "type": "compare", "title": "Before → after", "items": [
      { "label": "Transferred", "before": 1644, "after": 612, "unit": "KB", "better": "lower" } ] },
    { "type": "notes", "title": "Not verified", "items": ["Mobile app consumers: no access to the repository"] }
  ],
  "next": ["Approve the index migration on orders.created_at"]
}
```
- `status`: `ok`, `warn`, `fail`, `info`. `severity`: `critical`, `high`, `medium`, `low`, `info`.
- A table cell can be a string, a number, or `{ "text", "status" }` (shown as a pill).
- `compare.better`: `lower` (default) or `higher`.
- `{ "type": "diagram", "title": "…", "code": "<Mermaid source>" }` draws a diagram (ER, flow); the source stays shown if the library cannot load.
- Never put secrets, tokens, session cookies, passwords or personal data in the JSON: the page may be shared.
