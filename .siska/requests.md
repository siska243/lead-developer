# Requests










## T34 · Document plugin update, disable, enable in the README
- Status: ✅ done · Priority: P2 · Created: 2026-09-30 · Updated: 2026-09-30
- Instructions: 2026-09-30 add to the docs: claude plugin marketplace update siska, then claude plugin update siska-lead-developer@siska; disable, re-enable etc.
- Result: README: "Mettre à jour" expanded (order, restart / reload, version check), new "Désactiver et réactiver" (disable/enable, --scope, /plugin menu, settings gate/ledger); options checked against claude plugin --help

## T35 · Does everything work with Codex and other agents?
- Status: ✅ done · Priority: P2 · Created: 2026-09-30 · Updated: 2026-09-30
- Instructions: 2026-09-30 does all this also work with other models/agents like Codex etc.?
- Result: checked: install.sh --target <tmp> generates 12 commands incl. optimize/api-docs/data-model, absolute paths, no Claude placeholders, templates copied; README and compat/README: what works where, update (git pull + install.sh --force), disable (uninstall / agent settings). New commands not run inside Codex in this session (Codex check-code verified earlier, T9)
