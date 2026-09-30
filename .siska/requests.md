# Requests






## T29 · Data structure documentation (data model)
- Status: ✅ done · Priority: P2 · Created: 2026-09-30 · Updated: 2026-09-30
- Instructions: 2026-09-30 add the data structure to the plugin; add it to help, update the README etc.
- Result: data-model command + scripts/data-model.sh (Laravel 11+ introspection, SQLite, normalized JSON), Mermaid ER + dictionary + checks; verified on Rubix PostgreSQL read-only (229 tables, 351 FKs without index); demo https://claude.ai/artifact/JNP126CxkQNNyZEB1dAGjh

## T30 · Postman-like API documentation: shareable, with requests
- Status: ✅ done · Priority: P2 · Created: 2026-09-30 · Updated: 2026-09-30
- Instructions: 2026-09-30 something like Postman: document the API, share it, make requests from it; add it to help, update the README etc.
  - 2026-09-30: also the API data structure: what the API returns and what can be sent, with type, default value etc.; it must adapt to the technology and the work environment of whoever installs it.
- Result: api-docs command + scripts/api-docs.sh: Scalar interactive page with request client, Postman v2.1 collection, api-structures.md (type, required, default, enum, format, example), shared page; generator per stack; demo https://claude.ai/artifact/9f1mHjqaMtr2rXZZyLBL3t
