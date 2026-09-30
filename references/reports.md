# Reports

Every command result that is more than a few lines (audit-route, audit-package, check-code, optimize, document, a delivery review) is delivered **twice, with the same facts**:

1. **A visual report page**, built from `templates/report/report.html`:
   - write the data JSON (`templates/report/README.md`); `scripts/page-scan.sh --report` already writes it for a page scan;
   - `bash scripts/report.sh <data.json> --out <file.html>`;
   - the agent can publish a rich page (Claude Code: see `compat/claude-code.md`) → publish that file, private by default;
   - otherwise → `--standalone --out <project>/.siska/reports/<command>-<YYYYMMDD-HHMM>.html`, and check `.siska/reports/` is in the project's `.gitignore` (add the line and say so).
2. **A short terminal answer**: the summary printed by `report.sh` (verdict, key numbers), at most 3 more lines of what matters, then the **link on its own line**, last, so it is the first thing seen:
   ```
   ✔ Orders page — 3 fixes applied, 1 waiting for your yes
     ● Score: 42 → 78 /100   ● LCP: 5.1 → 2.1 s
   Report: https://… (or file:///…/.siska/reports/optimize-20260930-1740.html)
   ```

Rules:
- Same facts in both: never a number in the page that the terminal contradicts, never "done" in one and "not verified" in the other.
- Only measured or read facts; what was not measured goes in a `notes` section titled "Not verified".
- Never a secret, token, session cookie, password, personal data or `.env` value in the data: the page may be shared.
- One page per command run; a re-run (before → after) updates the same page when the agent can, else writes a new file.
- Short answers (help, settings, ticket table, a question to the user) stay plain text.
