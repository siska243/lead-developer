## T1 · Suivi des demandes (ID, statut, priorité, doublons)
- Status: ✅ done · Priority: P2 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: étiqueter chaque demande (T1…), statut fait / non fait / en cours / annulé / besoin d'info, `t1 <consigne>`, vérifier si déjà faite, importance
- Result: `references/requests.md`, commande `tickets`; testé sur 4 messages successifs (découpage, `t1`, doublon détecté); commit `6d17ce6`
- Question: –

## T2 · Bonnes pratiques, uniformité, design system à la lettre, humanizer
- Status: ✅ done · Priority: P2 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: code propre, maintenable, performant, sécurisé, uniforme; charte respectée à la lettre; pas plusieurs composants pour la même chose; norme humanize
  - 2026-09-28 (précisé): humanize = skill `humanizer`
- Result: règles dans `clean-code.md`, `design-system.md`, `workflow.md`; commit `6d17ce6`
- Question: –

## T3 · Expliquer simplement, sous-agents, économie de tokens
- Status: ✅ done · Priority: P2 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: toujours expliquer de façon simplifiée, utiliser des sous-agents si possible, ne pas consommer beaucoup de tokens
- Result: `references/agents.md`, étape "explain simply" du workflow; commit `6d17ce6`
- Question: –

## T4 · Réduire la taille de SKILL.md
- Status: ✅ done · Priority: P3 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: réduis le SKILL.md
- Result: ~1150 → ~600 mots, sans perte de règle; commit `6d17ce6`
- Question: –

## T5 · Bloquer le commit si les tests échouent, commande check-code
- Status: ✅ done · Priority: P1 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: les tests doivent passer avant d'accepter le commit; erreurs → commit bloqué; `/siska-lead-developer:check-code`; toujours l'utiliser avant de committer
- Result: hook du plugin + `pre-commit-gate.sh`, linters dans `check-project.sh`, `.siska/checks`; commit bloqué en réel (y compris `git -c … commit`); commit `c1734e9`
- Question: –

## T6 · Choisir quoi contrôler : front, back, mobile
- Status: ✅ done · Priority: P2 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: préciser ce qu'on veut checker : front, back, etc.
- Result: `--scope front,back,mobile`, `check-code --front/--back/--mobile`, lignes étiquetées dans `.siska/checks`; commit `c1734e9`
- Question: –

## T7 · Orchestrateur de skills et MCP
- Status: ✅ done · Priority: P2 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: mission "orchestrateur de Skills et MCP" (inventaire, recherche, vérification sécurité, accord, refus respecté, actions à haut risque)
- Result: `references/orchestration.md`, `list-capabilities.sh`, `vet-skill.sh`, commande `skills`; scénario Kubernetes testé, rien installé sans accord; commit `8d4371f`
- Question: –

## T8 · Documentation fonctionnelle puis technique, obligatoire
- Status: ✅ done · Priority: P2 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: documenter le code, les API, fonctionnellement l'application, humanize
  - 2026-09-28 (added): à chaque nouvelle fonctionnalité, doc fonctionnelle puis technique (appels API…)
- Result: `references/documentation.md`, commande `document`, checklist de livraison; testé sur `GET /orders`; commit `21a50da`
- Question: –

## T10 · Pouvoir passer le contrôle avant commit
- Status: ✅ done · Priority: P2 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: l'utilisateur peut aussi faire le skip
- Result: `SISKA_SKIP_GATE=1 git commit …` annoncé, règle "seulement sur demande explicite"; testé : pas de skip spontané, skip sur demande; commit `ac3290b`
- Question: –

## T11 · Imposer le suivi des demandes dans le plugin, sans oubli possible
- Status: ✅ done · Priority: P1 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: éviter ce genre d'oubli (suivi non tenu dans un fichier); l'ajouter dans le plugin pour ne rien rater, plus d'excuse
- Result: `scripts/ledger-hook.sh` + hooks `UserPromptSubmit`/`Stop` du plugin; 8 tests; testé en réel sur 2 messages (T1 puis T2 créés au bon format sans le demander); commit `ac3290b`
- Question: –
