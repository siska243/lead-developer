# Requests

## T9 · Utilisable avec Claude, Codex, Copilot…
- Status: ✅ done · Priority: P2 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: il faut que ce soit utilisable pour Claude, Codex, Copilot, etc.
- Result: commandes portables `siska-<cmd>` via `install.sh`, hook git `install-git-hook.sh`, `compat/README.md`; reconnues pour Codex, Copilot, OpenCode par le CLI skills; commit `038de15`
- Question: – (clôturé à la demande de l'utilisateur ; test réel dans Codex non fait : modèles refusés par le compte ChatGPT)

## T12 · Réduire les tokens du suivi des demandes
- Status: ✅ done · Priority: P1 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: utiliser le moins de tokens possible avec une qualité de code élevée, vraiment
- Result: archivage auto des tickets clos par le hook, ajout sans relecture, lecture ciblée, hook raccourci; fichier actif ~1265 → ~138 tokens; tests OK
- Question: –

## T13 · Activer / désactiver le hook pre-commit depuis le plugin
- Status: ✅ done · Priority: P1 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: comment désactiver le hook pre-commit ; impossible depuis mon plugin, on doit pouvoir l'activer et le désactiver
- Result: `settings.sh` + commande `settings` (gate/ledger, projet ou `--global`), hooks respectent le réglage ; 10 tests
- Question: –
