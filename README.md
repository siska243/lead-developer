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
| `/siska-lead-developer:optimize` | Optimisation du code : champs d'API que le front n'utilise pas, requêtes front inutiles, pages lourdes, code backend lent, code mort et dupliqué. Corrige après ton accord |
| `/siska-lead-developer:optimize https://app.local/orders` | Tu donnes le lien d'une page : il la scanne, te fait un résumé et un plan, l'applique sur une branche `perf/` (les points à risque attendent ton oui), puis montre avant → après |
| `/siska-lead-developer:optimize com.societe.app --flow .maestro/orders.yaml` | Mobile : mesure l'app sur un téléphone ou un émulateur (démarrage, images saccadées, mémoire), résumé, plan appliqué, avant → après |
| `/siska-lead-developer:optimize front --orders` | Seulement certaines parties (`api`, `front`, `back`, `dead`, cumulables), seulement ce qui contient `orders` |
| `/siska-lead-developer:api-docs` | Doc d'API façon Postman : page interactive pour lire et envoyer des requêtes, collection Postman (Postman, Insomnia, Bruno), champs envoyés et reçus avec type, obligatoire, défaut, valeurs possibles |
| `/siska-lead-developer:data-model` | Structure de données : explorateur interactif (zoom, déplacement, rotation, recherche, focus sur une table et ses voisines) et doc avec diagramme ER ; signale les tables sans clé primaire et les clés étrangères sans index |
| `/siska-lead-developer:mcp <quoi exposer>` | Ajouter / auditer un serveur MCP |
| `/siska-lead-developer:check-code` | Contrôle avant commit : tests, linters, secrets et clés en dur, `.env`. Commit refusé si quelque chose échoue |
| `/siska-lead-developer:check-code --front` | Idem, uniquement le front (aussi `--back`, `--mobile`, cumulables) |
| `/siska-lead-developer:document <fonctionnalité>` | Documentation : fonctionnelle, puis technique (appels API…) · `--functional`, `--api`, `--code` |
| `/siska-lead-developer:skills` | Skills et MCP installés · `find <besoin>` · `vet <source>` · `install <source>` (seulement après ton oui) |
| `/siska-lead-developer:settings gate off` | Désactive / réactive (`gate on`) le contrôle avant commit ; `ledger off` pour le suivi ; `--global` pour tous les projets |
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
- **Désactiver le contrôle** sans désactiver le plugin : `/siska-lead-developer:settings gate off`, puis `gate on` pour le réactiver. Le réglage vaut pour le projet (`.siska/settings`), ou pour tous tes projets avec `--global`. Tant qu'il est désactivé, chaque commit affiche un avertissement. Le suivi des demandes se désactive de la même façon : `settings ledger off`.
- **Passer le contrôle** pour un commit précis :
  - demande-le à l'agent (« skip le contrôle pour ce commit ») : il committe avec `SISKA_SKIP_GATE=1 git commit …` et le signale dans son rapport. Il ne le fait jamais sans ta demande ;
  - ou lance toi-même `SISKA_SKIP_GATE=1 git commit -m "…"`. Avec le hook git (autres agents), `git commit --no-verify` marche aussi ;
  - les commits que tu fais dans ton propre terminal ne passent pas par le hook du plugin Claude Code.
- Si les contrôles durent plus de 10 minutes, le hook s'arrête sans bloquer : lance alors `/siska-lead-developer:check-code` avant de committer.

### Aucun secret dans le code

Avant chaque commit, `scripts/secret-scan.sh` cherche dans les lignes ajoutées et les nouveaux fichiers :
- les clés privées, les tokens AWS, GitHub, GitLab, Slack, Stripe, Google, les clés d'API de type `sk-…`, les JWT ;
- les mots de passe dans les URL de connexion (`mysql://user:<mot-de-passe>@host`) ;
- les variables `password`, `secret`, `api_key`, `token`… qui reçoivent une valeur écrite en dur ;
- les fichiers de clés (`.pem`, `.key`, `.p12`, `id_rsa`…) et les `.env` suivis par git.

Ce contrôle tourne **toujours**, même avec `gate off` ou `SISKA_SKIP_GATE=1` : une clé committée reste dans l'historique git. Les références à des variables d'environnement (`env("DB_PASSWORD")`, `process.env.X`, `${VAR}`) et les valeurs d'exemple (`<your-token>`) passent. Une fausse alerte vérifiée (fixture de test) se marque avec un commentaire `siska:allow-secret` sur la ligne. Une clé déjà committée est compromise : il faut la changer.

### Historique git et CI

- `bash scripts/secret-scan.sh . --history` (ou `/siska-lead-developer:check-code --history`) scanne **tous les commits de toutes les branches**. Une clé committée il y a longtemps, même supprimée depuis, reste lisible dans chaque clone : il faut la changer. Les valeurs sont masquées dans le résultat (`AKIA****`).
- Une fausse alerte déjà dans l'historique se déclare dans `.siska/secrets-allow`, avec sa raison : `<commit> <fichier>:<ligne>`.
- **CI** : les hooks locaux se contournent (`--no-verify`, un autre poste, une modification sur le web). `templates/ci/github-actions.yml` et `templates/ci/gitlab-ci.yml` relancent sur chaque PR le scan de secrets (commits de la PR et historique complet), puis les tests et le lint. Siska propose de les ajouter à la CI existante du projet, jamais sans ton accord. Ce dépôt a la sienne : `.github/workflows/checks.yml`.

### Pas de co-auteur IA

Les messages de commit et les descriptions de PR décrivent le changement technique, sans ligne `Co-Authored-By:` d'un outil d'IA ni « Generated with … ». Le hook refuse ces commits (et `gh pr create/edit` dans Claude Code) ; le hook git `commit-msg` fait de même pour les autres agents. Un co-auteur humain reste accepté.

## Rapports visuels

Chaque résultat de commande (audits, `check-code`, `optimize`, `document`) arrive en deux formes, avec les mêmes chiffres :
- **une page de rapport** claire, en thème clair ou sombre et lisible sur mobile : verdict, indicateurs clés, tableaux, problèmes classés par gravité, avant → après, et ce qui n'a pas pu être vérifié. Dans Claude Code, c'est un artifact privé ; avec les autres agents, un fichier `.siska/reports/<commande>-<date>.html` à ouvrir dans le navigateur ;
- **un résumé court dans le terminal**, avec des couleurs et une animation pendant les scans longs quand c'est un vrai terminal, et **le lien du rapport sur la dernière ligne**.

Les rapports ne contiennent jamais de secret, de cookie de session ni de donnée personnelle. Format des données : `templates/report/README.md`.

### Pages derrière une connexion

`optimize <lien>` mesure la page avec Lighthouse, l'outil standard, le même moteur que Chrome DevTools et PageSpeed Insights. Si la page demande une connexion :

crée une session une fois, avec la méthode de ton choix (un **compte de test**, jamais un admin de production) :

```bash
# identifiant et mot de passe : connexion puis mesure dans le même Chrome (marche aussi avec les cookies de session)
SISKA_SCAN_USER='qa@exemple.fr' SISKA_SCAN_PASSWORD='…' bash scripts/page-scan.sh https://app.local/orders --login-url https://app.local/login
bash scripts/page-scan.sh https://app.local/orders --login-url https://app.local/login --ask   # saisie masquée : le mot de passe ne passe pas par l'agent
# token : placé dans le localStorage, là où ton front le range après la connexion
SISKA_SCAN_TOKEN='…' bash scripts/page-scan.sh https://app.local/orders --token-key auth_token
# manuel (captcha, 2FA) : un Chrome visible s'ouvre, tu te connectes et tu LAISSES LA FENÊTRE OUVERTE
bash scripts/page-scan.sh --login https://app.local/orders
bash scripts/page-scan.sh --logout                                # ferme et efface la session
```

La session vit dans un profil Chrome privé, hors du projet (`~/.cache/siska/chrome-profile`). Les cookies de session, sans date d'expiration, meurent quand Chrome se ferme : c'est pour ça que la connexion et la mesure se font dans le même Chrome. Le token et le mot de passe passent uniquement par des variables d'environnement : ils ne sont jamais affichés, écrits dans un fichier ou mis dans le rapport. Si tu donnes un token ou un mot de passe à l'agent dans le chat, il reste dans l'historique de la conversation : préfère `--ask`, ou un token de test à durée courte. Si un MCP navigateur (Playwright MCP, Chrome DevTools MCP) est installé, il sert en plus à mesurer les requêtes faites pendant les actions : filtres, tri, pagination. Sur un serveur de dev (Vite, `next dev`), un avertissement rappelle que les chiffres ne sont pas ceux de la production.

### Budgets de performance

Pour que tes pages ne redeviennent pas lourdes petit à petit :

```json
// .siska/perf-budget.json (commité)
{ "tolerance_pct": 10,
  "pages": { "dossiers": { "url": "http://localhost:4173/order-v2", "desktop": true,
             "budget": { "api_kb": 800, "transferred_kb": 1500, "lcp_ms": 2500, "duplicate_requests": 0 } } },
  "apps":  { "android": { "package": "com.societe.app", "flow": ".maestro/dossiers.yaml",
             "budget": { "cold_start_ms": 1500, "janky_pct": 5 } } } }
```

- `bash scripts/perf-budget.sh . run`, ou `/siska-lead-developer:check-code --perf`, mesure chaque page et chaque app, et **échoue** si une limite est dépassée.
- Il échoue aussi si une mesure se dégrade de plus de 10 % par rapport à la **référence** (`.siska/perf/<nom>.json`, la dernière mesure acceptée), même sous la limite.
- Après une optimisation, `optimize` propose de resserrer le budget et d'enregistrer la nouvelle référence (`--update-baseline`), avec ton accord.
- En CI : après le build et le démarrage de l'app, l'étape `perf-budget.sh . run` bloque la PR qui alourdit une page.
- Mesure toujours dans les mêmes conditions : build de production ou staging pour le web (jamais le serveur de dev), build release sur le même téléphone pour le mobile.

### Applications mobiles

La même commande marche pour React Native, Expo et Android, avec les outils standards du mobile, puisque Lighthouse ne mesure que le web :

```bash
bash scripts/mobile-scan.sh com.societe.app                                  # démarrage à froid, fluidité, mémoire, CPU, taille
bash scripts/mobile-scan.sh com.societe.app --flow .maestro/orders.yaml     # mesure pendant un parcours Maestro (écran précis, connexion)
```

Le script utilise `adb` et `dumpsys` sur un téléphone branché ou un émulateur, et Maestro pour rejouer un parcours. Les identifiants d'un compte de test passent en variables Maestro (`-e`), jamais dans le fichier du parcours. Il prévient quand les chiffres ne sont qu'indicatifs : build debug ou émulateur. Pour des chiffres réels, utilise un build release sur un téléphone de milieu de gamme. iOS se mesure avec Xcode Instruments. Le poids des réponses de l'API est vérifié dans le code et le backend, comme pour le web.

## Skills et MCP

Siska utilise d'abord les skills et MCP déjà installés, et ne charge que ceux utiles à la tâche. S'il en manque un :
1. il le cherche, avec `npx skills find` pour les skills et le registre officiel pour les MCP ;
2. il l'analyse sans l'exécuter (`scripts/vet-skill.sh` : scripts, hooks, accès réseau, secrets, commandes dangereuses, instructions cachées) ;
3. il te demande ton accord : oui, non, ou plus d'infos.

Un refus est définitif, et Siska continue sans le skill si c'est possible. Pour les actions à risque (production, suppression, `DROP`, déploiement, DNS…), il montre l'impact et le retour arrière, puis demande confirmation, ou refuse.

Exemples :
- « Il me manque un skill Kubernetes » : il vérifie ce qui est installé, cherche, analyse, puis te propose 1 à 3 skills à installer.
- « Optimise mon Docker pour la prod » : il combine l'expertise Docker, sécurité et performance, dans un seul plan.
- « Déploie cette application » : action à haut risque, il montre l'impact, le retour arrière, et attend ta confirmation.

## Documentation

Chaque nouvelle fonctionnalité, ou fonctionnalité modifiée, est documentée dans le même ticket. Sans sa documentation, le ticket n'est pas terminé.

1. **Fonctionnel** : à quoi elle sert, pour qui, le parcours, les règles, les écrans, les erreurs.
2. **Technique** : les appels API (route, authentification, paramètres, réponses, erreurs, exemples), les données, les jobs, les permissions.

Le code aussi est documenté : chaque classe, fonction publique, endpoint, job ou script nouveau ou modifié reçoit son commentaire de documentation (rôle, paramètres, retour, erreurs, effets de bord), et les commentaires expliquent le *pourquoi*. Le README reste juste : installer, configurer (noms des variables d'environnement), lancer, tester, déployer.

Tout est vérifié dans le code, rien n'est inventé, et le texte est écrit comme par un humain. La fiche va dans le dossier de documentation du projet, ou dans `docs/features/` s'il n'en a pas. Le fichier OpenAPI est mis à jour s'il existe.

## Documentation de l'API et structure de données

### Doc d'API façon Postman (`api-docs`)

À partir du fichier OpenAPI du projet, trois choses :
- **une page interactive** (`index.html`) : chaque route avec ce qu'elle accepte et ce qu'elle renvoie, un bouton **Test Request** et un client d'API pour envoyer de vraies requêtes, avec ton token saisi dans la page, jamais enregistré ;
- **une collection Postman** (`*.postman_collection.json`), importable dans Postman, Insomnia ou Bruno : un dossier par groupe, des exemples de corps, les variables `{{baseUrl}}` et `{{token}}` ;
- **la structure des données de l'API** (`api-structures.md`) : pour chaque route, les paramètres, les champs à envoyer et les champs renvoyés, avec le type, obligatoire ou non, la valeur par défaut, les valeurs possibles, le format, les limites et un exemple.

Pour partager la doc, publie-la en page (artifact) : elle se lit partout, mais sans envoyer de requêtes, qu'une page partagée ne peut pas faire. Donne aussi la collection. Pour tester, ouvre `index.html` ou importe la collection.

**Adapté à ta techno** : si le projet n'a pas de fichier OpenAPI, Siska propose le générateur de ton stack, qui lit tes vraies règles de validation et tes ressources. Il l'installe seulement après ton accord :

| Stack | Générateur |
|---|---|
| Laravel | Scramble (types, défauts, énumérations tirés des FormRequest et des API Resources) |
| FastAPI | intégré (`/openapi.json`) |
| Symfony | API Platform ou NelmioApiDocBundle |
| NestJS | `@nestjs/swagger` |
| Express / Fastify | `zod-to-openapi` (si tu valides avec Zod) ou `@fastify/swagger` |
| Django REST | drf-spectacular |
| Spring Boot | springdoc-openapi |
| Go | swag |

Si ton dépôt contient déjà une collection Postman, Insomnia ou Bruno, c'est celle-là qui est mise à jour.

```bash
bash scripts/api-docs.sh openapi.json --out docs/api --base-url http://localhost:8000/api
```

### Structure de données (`data-model`)

Lit le **vrai schéma** de la base, en lecture seule, sans jamais lire les lignes : tables, colonnes, types, valeurs par défaut, clés, index et relations.

**L'explorateur interactif** (`docs/data-model.html`, aussi partageable en page) est fait pour les gros schémas : des centaines de tables.
- Zoom à la molette ou au pincement, déplacement à la souris, rotation (⟲ ⟳), bouton pour tout cadrer.
- Recherche d'une table ou d'une colonne, puis clic : les colonnes (type, null, défaut, clé), les index et les relations dans les deux sens, cliquables.
- **Focus** sur une table et ses voisines, à 1 ou 2 niveaux, ou seulement elles. Plusieurs mises en page, tables déplaçables, lien direct `…/data-model.html#orders`.
- Couleur par domaine ; les clés étrangères sans index sont en pointillés orange, et le filtre « Issues only » isole les tables à corriger.
- Raccourcis : `/` recherche, `+` `-` zoom, `0` cadrer, `[` `]` rotation, `Esc` effacer.

Il écrit aussi `docs/data-model.md` (diagramme ER Mermaid et dictionnaire complet) et un rapport visuel. Il signale les tables sans clé primaire et les **clés étrangères sans index**. PostgreSQL ne les crée pas automatiquement, et leur absence ralentit les jointures et les suppressions.

- Laravel 11+ : l'introspection du framework, sur la connexion configurée.
- SQLite : `--sqlite fichier.db`.
- Autres stacks (Prisma, Django, Doctrine, TypeORM, Rails…) : le schéma est exporté avec l'outil du projet, puis passé en `--from-json`.
- Plus de 60 tables : un diagramme par domaine, avec `--only 'order|client'`.

Si la configuration pointe vers une base de production, Siska demande avant de s'y connecter.

```bash
bash scripts/data-model.sh . --html docs/data-model.html --markdown docs/data-model.md
```

## Technologies et dépendances à jour

- Un nouveau projet ou une nouvelle dépendance part sur la dernière version stable (LTS pour les runtimes et frameworks), vérifiée sur le registre au moment du choix.
- Les versions en fin de vie (PHP, Node, Python, Laravel, React Native…) sont signalées avec un plan de migration.
- `/siska-lead-developer:audit-package --outdated` est proposé quand un ticket touche aux dépendances, sur un projet non vérifié depuis un mois, et avant une mise en production : correctifs de sécurité tout de suite, versions patch et minor groupées, versions majeures une par une. Rien n'est mis à jour sans ton accord.

## Suivi des demandes

Chaque demande reçoit un numéro (`T1`, `T2`…), une priorité (`P1` urgent, `P2` normal, `P3` secondaire) et un statut :
⬜ à faire · 🔄 en cours · ✅ fait · ❓ besoin d'info · ❌ annulé.

- Écris `t3 <consigne>` pour compléter le ticket T3, et `t2 P1` pour changer sa priorité.
- Une nouvelle demande ne remplace pas les précédentes : elle entre dans la file.
- Une demande déjà faite n'est pas refaite : l'agent te demande ce qu'il faut améliorer.
- Chaque réponse se termine par le tableau des tickets.
- Le suivi est enregistré dans `.siska/requests.md`, à la racine du projet. À toi de décider si tu le commits ou si tu l'ajoutes au `.gitignore`.
- **Imposé par le plugin Claude Code** :
  - à chaque message, l'agent reçoit la liste des tickets ouverts et le format à respecter ;
  - il ne peut pas terminer sa réponse sans avoir mis à jour `.siska/requests.md`, avec au maximum 2 rappels pour éviter une boucle.

  Ce mécanisme n'est actif que dans un dépôt git. Codex, Copilot et les autres agents n'ont pas ces hooks : chez eux, seule la règle du skill s'applique.

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

## Codex, GitHub Copilot, OpenCode et autres agents

```bash
git clone https://github.com/siska243/lead-developer && cd lead-developer
bash scripts/install.sh                               # dans ~/.agents/skills
bash scripts/install-git-hook.sh /chemin/du/projet    # hooks pre-commit + commit-msg : contrôles, secrets, co-auteur IA
```

- Le skill principal et ses commandes sont installés sous les noms `siska-audit-route`, `siska-audit-package`, `siska-check-code`, `siska-document`, `siska-optimize`, `siska-settings`, `siska-skills`, `siska-tickets`, `siska-mcp` et `siska-help`.
- Pour appeler une commande :
  - Codex : `$siska-check-code`, ou `/skills` ;
  - Copilot : choisis ou cite `siska-check-code`.
- Pour un seul projet : `bash scripts/install.sh --target /chemin/du/projet/.agents/skills`.
- Désinstaller : `bash scripts/install.sh --uninstall` et `bash scripts/install-git-hook.sh /chemin/du/projet --uninstall`.
- Le hook git bloque tous les commits du dépôt, que ce soit un agent ou toi qui committe. Il ne remplace jamais un hook existant, ni husky ou lefthook : dans ce cas, il affiche la ligne à ajouter.
- Détails par agent : `compat/README.md`.

**Ne pas utiliser ce script pour Claude Code** : utilise le plugin. Le script refuse d'installer dans `.claude/skills` si le plugin y est déjà, pour éviter un doublon.

Options : `--link` (lien symbolique), `--force` (remplace en gardant une sauvegarde), `--dry-run` (aperçu).

## Scripts utilisables à la main

```bash
bash scripts/detect-stack.sh <projet>                  # stack réelle
bash scripts/security-audit.sh <projet> [--outdated]   # audit des dépendances
bash scripts/check-project.sh <projet> [--run-tests]   # contrôle avant livraison
bash scripts/secret-scan.sh <projet>                   # secrets et clés en dur dans les changements
bash scripts/page-scan.sh <url> [--report data.json]   # poids, requêtes, appels API et doublons d'une page (Lighthouse)
bash scripts/page-scan.sh --login <url>                # se connecter une fois pour scanner les pages protégées
bash scripts/mobile-scan.sh <package> [--flow f.yaml]  # performance d'une app Android (adb, Maestro)
bash scripts/perf-budget.sh . run [--update-baseline]  # budgets de performance des pages et apps
bash scripts/api-docs.sh openapi.json --out docs/api   # doc interactive, collection Postman, structures de l'API
bash scripts/data-model.sh . --html docs/data-model.html   # explorateur interactif du schéma (+ --markdown)
bash scripts/report.sh data.json --out r.html --standalone   # rapport visuel
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
