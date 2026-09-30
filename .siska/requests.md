# Requests








## T32 · Interactive data model explorer (zoom, pan, rotate, focus a table)
- Status: ✅ done · Priority: P1 · Created: 2026-09-30 · Updated: 2026-09-30
- Instructions: 2026-09-30 data-model and api are good, but with 229 tables I cannot zoom in or out on a table, nor rotate etc.; it is really static.
- Result: templates/data-model/explorer.html (Cytoscape 3.34.3) via data-model.sh --html/--artifact; zoom, pan, rotate, search, table sheet, focus 1-2 levels, layouts, deep link; fixed invisible nodes (label sizing) and hidden overlay; checked on Rubix 229 tables (layout ~2 s); v1.13.0; Rubix explorer https://claude.ai/artifact/Q66i1NtY7ctx7DCGMDPdN4
