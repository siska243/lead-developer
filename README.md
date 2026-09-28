# Siska Lead Developer

Un **Skill** pour agent de développement IA (Claude Code, Codex, Gemini CLI, Copilot CLI ou tout agent compatible Skills). Une fois installé, l'agent travaille comme un **Lead Developer senior** et non comme un simple générateur de code :

```text
Comprendre → Explorer → Planifier → Questionner → Concevoir → Implémenter → Tester → Auditer → Vérifier → Corriger → Livrer
```

Ses règles prioritaires :
- sécurité d'abord ;
- **zéro régression** ;
- production first ;
- ne jamais inventer un fichier, une route, une colonne ou une variable d'environnement ;
- faire exactement ce qui est demandé ;
- pas de dette technique volontaire ;
- rien n'est déclaré « terminé » sans vérification.

Le dépôt fournit deux skills :

| Skill | Commande | Rôle |
|-------|----------|------|
| `siska-lead-developer` | `/siska-lead-developer` | Skill principal : tickets, bugs, TMA, nouveau projet, review, audit, UI/UX, performance |
| `siska-lead-mcp` | `/siska-lead-mcp` | Intégrer, étendre ou auditer un serveur MCP dans une application |

---

## 1. Prérequis

- `bash` (Linux, macOS, WSL).
- Un agent compatible Skills.
- Facultatif : les outils du projet analysé (`composer`, `npm`/`pnpm`/`yarn`/`bun`, `pip-audit`, `git`). Les scripts les utilisent s'ils sont installés et signalent `SKIP` sinon.

---

## 2. Installation

Toutes les commandes se lancent **depuis la racine de ce dépôt**.

### Claude Code

```bash
# Copie (recommandé pour un usage stable)
bash scripts/install.sh --target ~/.claude/skills

# Lien symbolique (recommandé si tu modifies le skill : les changements du dépôt sont pris en compte directement)
bash scripts/install.sh --target ~/.claude/skills --link

# Pour un seul projet au lieu de tous : dans le dossier du projet
bash /chemin/vers/siska-lead-developper/scripts/install.sh --target .claude/skills
```

### Codex, Gemini CLI, Copilot CLI et autres agents lisant `~/.agents/skills`

```bash
bash scripts/install.sh            # cible par défaut : ~/.agents/skills
```

### Autre agent

Indique son dossier de skills avec `--target <dossier>`. Voir `compat/README.md`.

### Options

| Option | Effet |
|--------|-------|
| `--target DIR` | Dossier de skills cible (défaut : `~/.agents/skills`) |
| `--link` | Crée des liens symboliques vers ce dépôt au lieu de copier |
| `--force` | Remplace une installation existante, après l'avoir déplacée en `<nom>.bak.<horodatage>` |
| `--dry-run` | Affiche ce qui serait fait, sans rien modifier |
| `--uninstall` | Désinstalle (voir § 6) |

**Sécurité** : l'installation n'écrase jamais rien en silence. Si un dossier `siska-lead-developer` ou `siska-lead-mcp` existe déjà, le script s'arrête, sauf avec `--force`, qui garde une sauvegarde.

### Vérifier l'installation

```bash
ls -l ~/.claude/skills | grep siska      # (ou ton --target)
```

Puis **redémarre la session de l'agent** : les skills ne sont chargés qu'au démarrage. Dans Claude Code, tape `/` : `siska-lead-developer` et `siska-lead-mcp` doivent apparaître dans la liste.

---

## 3. Utilisation

### Déclenchement automatique

L'agent charge le skill tout seul quand ta demande correspond à une tâche de développement : ticket, bug, maintenance, nouveau projet, review, audit, UI, animation, MCP. Il suffit de décrire le besoin normalement :

```text
Ajoute un filtre par statut sur l'API GET /orders.
Corrige le bug : les notifications push partent en double sur Android.
Audite les dépendances de ce projet avant la mise en prod.
```

### Appel explicite (recommandé pour être sûr qu'il s'applique)

```text
/siska-lead-developer Ajoute un filtre par statut sur l'API GET /orders
/siska-lead-developer Fais une review du diff avant que je merge
/siska-lead-developer TMA : la page facture affiche un total faux quand il y a une remise
/siska-lead-developer Nouveau projet : API FastAPI + app Expo pour la prise de rendez-vous
/siska-lead-mcp Expose la consultation des commandes à un client MCP, en lecture seule
```

### Ce que fait l'agent avec le skill

1. **Détecte la stack** (`scripts/detect-stack.sh`) et lit le code réellement concerné : routes, services, modèles, composants, migrations, tests…
2. **Charge seulement les références utiles** : `tma.md` pour un bug, `ux.md` et `design-system.md` pour de l'UI, `security.md` pour de l'auth, `mcp.md` pour du MCP, etc.
3. **Analyse les impacts** : ce qui est touché directement, indirectement (appelants, jobs, clients mobiles, permissions…), et répond à « qu'est-ce qui pourrait casser ? ».
4. **Planifie** (mode plan pour les tâches non triviales) et **te pose des questions** quand une décision t'appartient ou qu'une information manque. Il ne devine pas.
5. **Implémente le minimum nécessaire**, en respectant les conventions du projet.
6. **Vérifie** : tests existants, nouveaux tests si nécessaire, audit de dépendances si pertinent, `scripts/check-project.sh`.
7. **Relit le diff** : chaque modification est-elle nécessaire au ticket ?
8. **Livre un compte rendu** : ce qui a changé, comment c'est vérifié (vrais résultats de commandes), les limites, et les problèmes hors scope proposés en tickets séparés (jamais corrigés d'office).

### Utiliser les autres skills et MCP installés

Le skill demande à l'agent d'utiliser les outils disponibles quand ils réduisent le risque ou vérifient le résultat. Pour Claude Code, `compat/claude-code.md` associe chaque étape aux skills et MCP qui peuvent être installés, par exemple :
- `superpowers:*`, `investigate`, `review`, `security-review`, `qa`, `browse` ;
- `impeccable`, `ui-ux-pro-max`, `animate`, `animate-expo` ;
- les skills `expo:*`, les MCP Remotion, Linear, Figma…

Ceux qui ne sont pas installés sont simplement ignorés.

### Intégration MCP (`/siska-lead-mcp`)

L'agent suit les 17 étapes de `references/mcp.md` :
- analyse de l'application, de l'auth et des permissions existantes ;
- proposition d'architecture, puis **questions** : quelles capacités exposer, quels scopes, quel serveur OAuth ;
- génération à partir de `templates/mcp/` ou du SDK officiel du framework (`laravel/mcp`, `symfony/mcp-bundle`, `mcp/sdk`, SDK Python `mcp`) ;
- tests, audit de sécurité et contrôle de non-régression.

Règles appliquées :
- outils spécialisés, un scope par capacité ;
- aucun outil générique `run_sql` / `run_shell` ;
- secrets OAuth uniquement en variables d'environnement.

---

## 4. Scripts utilisables à la main

Tous sont **en lecture seule** sur le projet analysé. Seule exception : `--run-tests`, qui lance les tests du projet. Chaque script a une aide `--help`.

```bash
bash scripts/detect-stack.sh /chemin/du/projet
bash scripts/security-audit.sh /chemin/du/projet [--outdated]
bash scripts/check-project.sh /chemin/du/projet [--run-tests]
```

| Script | Ce qu'il fait | Code de sortie |
|--------|---------------|----------------|
| `detect-stack.sh` | Langages, frameworks, package managers, frameworks de test, SDK MCP, librairies d'animation, Docker, CI, AWS, état git. Gère les monorepos (profondeur 3, ignore `node_modules`/`vendor`). | 0, ou 2 si le dossier est invalide |
| `security-audit.sh` | Lance `composer audit`, `npm`/`pnpm`/`yarn`/`bun audit`, `pip-audit` selon le lockfile trouvé. Ne met **rien** à jour. | 0 si aucune vulnérabilité ; 1 si vulnérabilités, erreur ou aucun audit possible |
| `check-project.sh` | Avant livraison : branche, changements non commités, `.env` suivi par git, secrets et `dd()`/`console.log` dans le diff, commandes de test détectées. | 0 si rien de bloquant ; 1 si bloquant |

---

## 5. Mise à jour

- **Installé avec `--link`** : rien à faire. `git pull` dans ce dépôt, puis redémarre la session de l'agent.
- **Installé par copie** : `git pull`, puis réinstalle en gardant une sauvegarde de l'ancienne version :
  ```bash
  bash scripts/install.sh --target ~/.claude/skills --force
  ```

---

## 6. Désinstallation

```bash
# Voir ce qui sera supprimé, sans rien toucher
bash scripts/install.sh --uninstall --target ~/.claude/skills --dry-run

# Désinstaller
bash scripts/install.sh --uninstall --target ~/.claude/skills
```

Utilise le même `--target` que pour l'installation. Sans `--target`, c'est `~/.agents/skills`.

Ce que fait `--uninstall` :
- **Lien symbolique** (install `--link`) : supprime seulement le lien. Ce dépôt n'est pas touché.
- **Copie** : supprime le dossier seulement si son `SKILL.md` déclare bien `siska-lead-developer` ou `siska-lead-mcp`. Tout autre dossier du même nom est laissé en place et signalé.
- **Sauvegardes** `*.bak.*` créées par `--force` : conservées. Supprime-les à la main si tu n'en veux plus :
  ```bash
  ls -d ~/.claude/skills/siska-lead-*.bak.*
  rm -rf ~/.claude/skills/siska-lead-developer.bak.<horodatage>
  ```

Redémarre ensuite la session de l'agent.

Désinstallation manuelle, sans le script :
```bash
rm ~/.claude/skills/siska-lead-developer ~/.claude/skills/siska-lead-mcp        # install --link
rm -rf ~/.claude/skills/siska-lead-developer ~/.claude/skills/siska-lead-mcp    # install par copie
```

---

## 7. Dépannage

| Problème | Solution |
|----------|----------|
| `/siska-lead-developer` n'apparaît pas | Redémarre la session de l'agent ; vérifie `ls -l <target>` et que `<target>/siska-lead-developer/SKILL.md` existe |
| `already exists. Re-run with --force` | Une installation existe déjà : `--force` (avec sauvegarde) ou `--uninstall` d'abord |
| Le skill ne se déclenche pas tout seul | Appelle-le explicitement : `/siska-lead-developer <demande>` |
| `SKIP [...] xxx not installed` dans l'audit | Installe l'outil (`pip install pip-audit`, etc.) ou lance l'audit dans l'environnement du projet |
| `RESULT: no audit could run` | Aucun lockfile ou aucun outil : les dépendances **ne sont pas** vérifiées |
| `Permission denied` sur un script | Lance-le avec `bash scripts/<script>.sh` |

---

## 8. Structure du dépôt

```text
SKILL.md                 identité, règles, workflow, chargement des références
references/              détails par domaine, chargés à la demande
  workflow.md tma.md new-project.md clean-code.md git.md security.md dependencies.md
  testing.md performance.md design-system.md ux.md motion-design.md mcp.md
scripts/                 detect-stack, security-audit, check-project, install (+ lib.sh partagé)
templates/mcp/           serveur TypeScript (stdio + HTTP, OAuth, scopes, tests), guide OAuth, config client
compat/                  couches spécifiques par agent (claude-code.md…)
skills/siska-lead-mcp/   point d'entrée /siska-lead-mcp
tests/                   auto-tests des scripts
CLAUDE.md                cahier des charges du skill
```

Le cœur (`SKILL.md`, `references/`, `scripts/`, `templates/`) est indépendant du fournisseur d'IA. Tout ce qui est spécifique à un agent est dans `compat/`.

---

## 9. Tests (développement du skill)

```bash
bash tests/scripts.test.sh                                  # scripts (install, désinstallation, détection, audit, contrôle)
npx shellcheck -x -P scripts scripts/*.sh tests/*.sh        # qualité des scripts
cd templates/mcp/server && npm install && npm test          # template MCP
```

Voir `CONTRIBUTING.md` pour contribuer.

## Licence

MIT – voir `LICENSE`.
