# Siska Lead Developer

Fait travailler ton agent IA comme un **Lead Developer senior** : zéro régression, sécurité, rien d'inventé, scope respecté, tests avant « terminé ».

## Commandes

| Commande | Rôle |
|----------|------|
| `/siska-lead-developer:help` | Liste toutes les commandes |
| `/siska-lead-developer:siska-lead-developer <tâche>` | N'importe quelle tâche de dev (ticket, bug, TMA, review, nouveau projet, UI). Se déclenche aussi tout seul. |
| `/siska-lead-developer:audit-route` | Audit sécurité de toutes les routes API |
| `/siska-lead-developer:audit-route --orders` | Audit des routes qui contiennent `orders` |
| `/siska-lead-developer:audit-package` | Dépendances : vulnérabilités, paquets abandonnés ou non maintenus, paquets inutilisés (désinstallés après ton accord) |
| `/siska-lead-developer:audit-package --outdated` | Idem + paquets obsolètes |
| `/siska-lead-developer:mcp <quoi exposer>` | Ajouter / auditer un serveur MCP |
| `/siska-lead-developer:check-code` | Contrôle avant commit : tests, linters, secrets, `.env`. Commit refusé si quelque chose échoue |
| `/siska-lead-developer:check-code --front` | Idem, uniquement le front (aussi `--back`, `--mobile`, cumulables) |
| `/siska-lead-developer:tickets` | Demandes en cours (T1, T2…) avec statut et priorité · `--all` pour toutes |
| `/siska-lead-developer:tickets t2 done` | Modifier un ticket : `done`, `todo`, `progress`, `cancel`, `info`, `P1`–`P3`, ou ajouter une consigne |

Les audits ne modifient rien : ils rendent un rapport, puis te demandent quoi corriger.

## Commit bloqué si les contrôles échouent

Le plugin installe un hook : avant chaque `git commit` lancé par Claude, il exécute les tests, les linters et la recherche de secrets. Si l'un d'eux échoue, **le commit est bloqué** et la raison s'affiche.

- Les commandes sont détectées automatiquement :
  - PHP : `composer test`, `php artisan test`, Pest, PHPUnit, Pint, PHPStan ;
  - JS/TS : les scripts `test`, `lint` et `typecheck` du `package.json` ;
  - Python : `pytest` et `ruff`.
- Classement automatique :
  - **back** : PHP, Python, Node côté serveur ;
  - **front** : React, Next.js, Vue, Vite… ;
  - **mobile** : Expo, React Native.
- Pour choisir exactement quoi lancer, crée `.siska/checks` à la racine du projet, avec une commande par ligne. Tu peux étiqueter une ligne : `front: npm run lint`, `back: php artisan test`.
- Le hook avant commit contrôle toujours tout. `check-code --front` sert à contrôler une seule partie pendant que tu travailles.
- Les commits que tu fais toi-même dans ton terminal ne passent pas par ce hook.
- Si les contrôles durent plus de 10 minutes, le hook s'arrête sans bloquer : lance alors `/siska-lead-developer:check-code` avant de committer.

## Suivi des demandes

Chaque demande reçoit un numéro (`T1`, `T2`…), une priorité (`P1` urgent, `P2` normal, `P3` secondaire) et un statut :
⬜ à faire · 🔄 en cours · ✅ fait · ❓ besoin d'info · ❌ annulé.

- Écris `t3 <consigne>` pour compléter le ticket T3, et `t2 P1` pour changer sa priorité.
- Une nouvelle demande ne remplace pas les précédentes : elle entre dans la file.
- Une demande déjà faite n'est pas refaite : l'agent te demande ce qu'il faut améliorer.
- Chaque réponse se termine par le tableau des tickets.
- Le suivi est enregistré dans `.siska/requests.md`, à la racine du projet. À toi de décider si tu le commits ou si tu l'ajoutes au `.gitignore`.

## Installer (Claude Code)

Dans Claude Code :

```text
/plugin marketplace add siska243/lead-developer
/plugin install siska-lead-developer@siska
```

Ou depuis le terminal :

```bash
claude plugin marketplace add siska243/lead-developer
claude plugin install siska-lead-developer@siska
```

Erreur `Cannot add marketplace "siska": its network source differs…` : le catalogue `siska` est déjà déclaré depuis une autre source (par exemple un clone local). Lance `/plugin marketplace remove siska`, puis recommence.

Depuis un clone local, remplace `siska243/lead-developer` par le chemin du dossier. Ensuite, redémarre Claude Code (ou lance `/reload-plugins`), puis tape `/siska-lead-developer:help`.

## Mettre à jour

```bash
claude plugin marketplace update siska
claude plugin update siska-lead-developer@siska
```

Avec une installation depuis un clone local : `git pull`, puis `/reload-plugins`.

## Désinstaller

Dans Claude Code : `/plugin`, onglet **Installed**, `siska-lead-developer`, puis **Uninstall**.

Ou depuis le terminal :

```bash
claude plugin uninstall siska-lead-developer@siska
claude plugin marketplace remove siska      # retire aussi le catalogue
```

## Autres agents (Codex, Gemini CLI, Copilot CLI…)

Seul le skill principal est installé, sans les commandes `:xxx` qui sont propres à Claude Code.
**Ne pas utiliser ce script pour Claude Code** : utilise le plugin. Le script refuse d'installer dans `.claude/skills` si le plugin y est déjà, pour éviter un doublon.

```bash
bash scripts/install.sh                      # dans ~/.agents/skills (--target DIR pour un autre dossier)
bash scripts/install.sh --uninstall          # désinstaller
```

Options : `--link` (lien symbolique), `--force` (remplace en gardant une sauvegarde), `--dry-run` (aperçu).

## Scripts utilisables à la main

```bash
bash scripts/detect-stack.sh <projet>                  # stack réelle
bash scripts/security-audit.sh <projet> [--outdated]   # audit des dépendances
bash scripts/check-project.sh <projet> [--run-tests]   # contrôle avant livraison
```

## Développer le skill

```bash
bash tests/scripts.test.sh
cd templates/mcp/server && npm install && npm test
claude plugin validate .
```

Structure :
- `SKILL.md` : règles principales ;
- `references/` : détails chargés à la demande ;
- `skills/` : les commandes `:xxx` ;
- `scripts/` ;
- `templates/mcp/` ;
- `compat/` : couches spécifiques à chaque agent.

Voir `CONTRIBUTING.md`. Licence MIT.
