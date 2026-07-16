# Plan: Ajout d'un endpoint /metrics Prometheus pour site_lockbits

## TL;DR

> **Résumé**: Ajouter un endpoint `/metrics` au site PHP lockbits (site_lockbits) pour exporter 6 métriques au format Prometheus, mettre à jour l'infrastructure Docker (réseaux, configs Prometheus), et créer un dashboard Grafana provisionné.
>
> **Livrables**:
> - Fichier `site_lockbits/metrics.php` (endpoint Prometheus, PHP pur)
> - Modifications Dockerfile (marqueur de temps de build)
> - Modifications `.htaccess` (sécurité /metrics)
> - Mise à jour réseau : `site-web` ajouté au réseau `monitoring` (préprod + prod)
> - Nouveau job `lockbits_site` dans les 3 configs Prometheus
> - Dashboard Grafana `site-dashboard.json` (UID: `lockbits-site`)
> - Mise à jour des tests smoke CI (`tests/smoke_site.py`)
>
> **Effort estimé**: Court (10 tâches + 4 vérification)
> **Exécution parallèle**: OUI — 3 vagues parallèles
> **Chemin critique**: metrics.php → smoke tests → vérification finale

---

## Contexte

### Demande originale
Ajouter un endpoint `/metrics` au site lockbits (PHP 8.2/Apache) pour permettre à Prometheus de scraper des métriques essentielles : santé de la BDD, nombre d'utilisateurs/tickets, mémoire PHP, temps depuis le démarrage, compteur de requêtes.

### Résumé de l'interview
**Décisions clés**:
- **Librairie Prometheus**: PHP PUR (pas de `promphp/prometheus_client_php`) — ~60 lignes d'echo, zéro dépendance, pas de `composer install` dans le Dockerfile
- **Métriques**: 6 métriques essentielles (db_health, users_total, tickets_total, php_memory_bytes, php_uptime_seconds, http_requests_total)
- **Dashboard Grafana**: Oui, provisionné dans le repo (UID: `lockbits-site`)
- **Réseau monitoring**: Ajouté à `site-web` dans les docker-compose préprod et prod
- **Monitoring local**: NON — pas de Prometheus/Grafana dans le docker-compose de dev
- **Targets Prometheus**: Noms de containers (`lockbits_web`, `lockbits_web_preprod`) sur port 80

### Résultats de l'exploration
- `site_lockbits/.htaccess` : les règles de réécriture ciblent uniquement `/client/*` → `/metrics` n'est PAS affecté (safety renforcée)
- `site_lockbits/Dockerfile` : pas de `composer install` actuel, pas besoin d'en ajouter (PHP pur)
- `site_lockbits/client/db.php` : singleton PDO avec `ERRMODE_EXCEPTION`
- `site_lockbits/client/config.php` : variables d'env Docker, pas de secrets exposés
- `docker/prometheus/prometheus.{yml,preprod.yml,prod.yml}` : pattern container names pour éviter round-robin Dokploy
- `docker-compose.preprod.yml` et `docker-compose.prod.yml` : `site-web` seulement sur réseau `frontend` (pas `monitoring`)
- `docker/grafana/provisioning/dashboards/edr-dashboard.json` : template avec `__inputs` pour datasource Prometheus (uid: `prometheus`)
- `tests/smoke_site.py` : tests actuels ne vérifient pas `/metrics`

---

## Objectifs du travail

### Objectif principal
Permettre à Prometheus de scraper 6 métriques depuis le site lockbits, et les visualiser dans Grafana.

### Livrables concrets
- `site_lockbits/metrics.php` — endpoint Prometheus (PHP pur, format exposition text)
- `site_lockbits/Dockerfile` — ajout marqueur `.lockbits_start`
- `site_lockbits/.htaccess` — RewriteCond sécurité pour `/metrics`
- `docker-compose.preprod.yml` — réseau `monitoring` ajouté à `site-web`
- `docker-compose.prod.yml` — réseau `monitoring` ajouté à `site-web`
- `docker/prometheus/prometheus.yml` — job `lockbits_site`
- `docker/prometheus/prometheus.preprod.yml` — job `lockbits_site`
- `docker/prometheus/prometheus.prod.yml` — job `lockbits_site`
- `docker/grafana/provisioning/dashboards/site-dashboard.json` — dashboard Grafana
- `tests/smoke_site.py` — vérification `/metrics`

### Définition de "Fait"
- [ ] `curl http://localhost:8080/metrics` retourne 200 et du texte au format Prometheus
- [ ] Les métriques listées apparaissent dans le body
- [ ] Prometheus peut scraper le endpoint (vérifié via `up{job="lockbits_site"}`)
- [ ] Dashboard Grafana `lockbits-site` affiche les métriques
- [ ] Tous les tests smoke passent (y compris les nouveaux checks /metrics)

### Doit inclure
- 6 métriques au format Prometheus exposition text
- Gestionnaire d'erreur PDO (db_health=0 sans crash)
- Compteur de requêtes persistant (fichier avec LOCK_EX)
- Marqueur de temps de build Docker pour l'uptime
- Target Prometheus sur port 80 pour le site
- Réseau `monitoring` partagé entre Prometheus et site-web

### Ne doit PAS inclure
- Aucune dépendance Composer (pas de `composer install`)
- Aucune refactorisation du code PHP existant
- Aucune modification de EDR, Alloy, Loki, ou des autres services
- Aucun changement du docker-compose local (dev)
- Aucune règle d'alerting Prometheus
- Aucune exposition de secrets, PII, ou chemins serveur dans `/metrics`
- Aucun changement de version PHP ou config Apache/MySQL

---

## Stratégie de vérification

> **ZÉRO INTERVENTION HUMAINE** — toute vérification est exécutée par un agent. Aucune exception.

### Décision de test
- **Infrastructure existante**: OUI — `tests/smoke_site.py` (Python/requests)
- **Tests automatisés**: OUI (après implémentation)
- **Framework**: pytest + requests (existants)
- **QA exécutée par agent**: Toujours (scénarios détaillés pour chaque tâche)

### Politique QA
Chaque tâche DOIT inclure des scénarios QA exécutés par agent.
Les preuves sont sauvegardées dans `.sisyphus/evidence/task-{N}-{scenario}.{ext}`.

- **Frontend/API**: Bash (curl) — requêtes HTTP, assertions sur statut + body
- **Infrastructure**: Bash — grep dans fichiers, vérification de présence

---

## Stratégie d'exécution

### Vagues d'exécution parallèles

```
Vague 1 (Fondations — parallélisable immédiatement):
├── Tâche 1: metrics.php (endpoint Prometheus PHP pur)
├── Tâche 2: Dockerfile (marqueur .lockbits_start)
└── Tâche 3: .htaccess (safety RewriteCond)

Vague 2 (Infrastructure — MAX PARALLÉLISME, dépend de Vague 1: partiel):
├── Tâche 4: docker-compose.preprod.yml (réseau monitoring)
├── Tâche 5: docker-compose.prod.yml (réseau monitoring)
├── Tâche 6: prometheus.yml (job lockbits_site)
├── Tâche 7: prometheus.preprod.yml (job lockbits_site)
├── Tâche 8: prometheus.prod.yml (job lockbits_site)
├── Tâche 9: site-dashboard.json (dashboard Grafana)
└── Tâche 10: smoke_site.py (test CI /metrics)

Vague FINALE (après TOUTES les tâches — 4 revues parallèles):
├── F1: Plan Compliance Audit (oracle)
├── F2: Code Quality Review (unspecified-high)
├── F3: Real Manual QA (unspecified-high + playwright)
└── F4: Scope Fidelity Check (deep)

Chemin critique: Tâche 1 → Tâche 10 → F1-F4
Parallélisme maximum: 7 (Vague 2)
Accélération: ~60% plus rapide que séquentiel
```

---

## TODOs

- [x] 1. Créer `site_lockbits/metrics.php` — endpoint Prometheus (PHP pur)

  **Quoi faire**:
  - Créer `/site_lockbits/metrics.php` à la racine (accessible via `GET /metrics`)
  - Commencer par `<?php declare(strict_types=1);`
  - `require_once __DIR__ . '/client/db.php'` et `__DIR__ . '/client/config.php'` pour la connexion BDD
  - Utiliser `db()` (singleton PDO existant) pour les requêtes
  - Envelopper tout le bloc DB dans un try/catch `PDOException` → `$dbHealth = 0` et valeurs par défaut à zéro, sans jamais crasher
  - Métriques à exposer (format Prometheus exposition text, `Content-Type: text/plain; version=0.0.4`) :

    | Métrique | Type | Source |
    |---|---|---|
    | `lockbits_db_health` | gauge | `1` si PDO connecté, `0` si PDOException |
    | `lockbits_users_total` | gauge | `SELECT COUNT(*) FROM users` |
    | `lockbits_tickets_total{status="open/in_progress/closed"}` | gauge | `SELECT status, COUNT(*) FROM tickets GROUP BY status` |
    | `lockbits_php_memory_bytes` | gauge | `memory_get_usage(true)` |
    | `lockbits_php_uptime_seconds` | gauge | `time() - (int)file_get_contents(__DIR__.'/.lockbits_start')` |
    | `lockbits_http_requests_total` | counter | Fichier `metrics_counter.txt` avec incrément atomique (`LOCK_EX`) |

  - Pour `lockbits_php_uptime_seconds` : lire `.lockbits_start` (créé par Dockerfile), fallback sur `$_SERVER['REQUEST_TIME']` si absent
  - Pour `lockbits_http_requests_total` : fichier texte `metrics_counter.txt` à la racine, lu puis incrémenté avec `flock()` (LOCK_SH puis LOCK_EX)
  - Header `Content-Type: text/plain; version=0.0.4` AVANT tout echo
  - Ne PAS exposer : PII, chemins de fichiers, variables d'env, credentials
  - Ne PAS utiliser de librairies Composer — PHP pur uniquement

  **Profil agent recommandé**:
  - **Catégorie**: `unspecified-high`
    - Raison: création d'un fichier PHP unique avec logique métier (DB queries, error handling, file I/O)
  - **Compétences**: aucune (PHP natif, pas de framework)
  - **Compétences évaluées mais omises**: aucune

  **Parallélisation**:
  - **Parallélisable**: NON (bloque la vague 2)
  - **Groupe**: Vague 1
  - **Bloque**: Tâche 10 (smoke tests)
  - **Bloqué par**: Aucune (démarre immédiatement)

  **Références**:
  - `site_lockbits/client/db.php:6-22` — Singleton PDO à réutiliser : `db()` retourne PDO
  - `site_lockbits/client/config.php:25-36` — Constantes DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASS
  - `site_lockbits/Dockerfile:32` (après modification) — emplacement du fichier `.lockbits_start`
  - Format Prometheus: `https://prometheus.io/docs/instrumenting/exposition_formats/` — format texte ligne par ligne

  **Critères d'acceptation**:

  **Scénarios QA (OBLIGATOIRE)**:

  ```
  Scénario: Vérifier que /metrics répond avec les métriques attendues
    Outil: Bash (curl)
    Préconditions: Aucune (le fichier est un endpoint PHP accessible même sans BDD)
    Étapes:
      1. cd site_lockbits && php -r "
          \$_SERVER['REQUEST_TIME'] = time();
          ob_start();
          require 'metrics.php';
          \$output = ob_get_clean();
          echo \$output;
        " 2>/dev/null | head -5
    Résultat attendu: Le texte commence par '# HELP' ou '# TYPE' ou un nom de métrique. Ne PAS avoir d'erreur PHP fatale.
    Preuve: .sisyphus/evidence/task-1-php-syntax.txt

  Scénario: Vérifier que metrics.php a la bonne syntaxe PHP
    Outil: Bash
    Préconditions: Fichier existe
    Étapes:
      1. php -l site_lockbits/metrics.php
    Résultat attendu: "No syntax errors detected"
    Preuve: .sisyphus/evidence/task-1-lint.txt
  ```

  **Preuve à capturer**:
  - [ ] `task-1-php-syntax.txt` — sortie de l'exécution PHP
  - [ ] `task-1-lint.txt` — résultat de `php -l`

  **Commit**: OUI (groupe avec 2, 3)
  - Message: `feat: add /metrics endpoint for Prometheus scraping`
  - Fichiers: `site_lockbits/metrics.php`

- [x] 2. Modifier `site_lockbits/Dockerfile` — marqueur `.lockbits_start`

  **Quoi faire**:
  - Ajouter `RUN date +%s > /var/www/html/.lockbits_start` APRÈS la ligne `COPY . /var/www/html/` (ligne 32) et AVANT `RUN chown -R www-data:www-data /var/www/html` (ligne 35)
  - Ce fichier stocke le timestamp Unix de la construction de l'image Docker
  - metrics.php le lit pour calculer `lockbits_php_uptime_seconds`

  **Profil agent recommandé**:
  - **Catégorie**: `quick`
    - Raison: une seule ligne à ajouter dans un fichier existant
  - **Compétences**: aucune

  **Parallélisation**:
  - **Parallélisable**: OUI (indépendant de task 1)
  - **Groupe**: Vague 1
  - **Bloque**: Aucune
  - **Bloqué par**: Aucune

  **Références**:
  - `site_lockbits/Dockerfile:32-36` — emplacement exact : entre COPY et chown
  - `site_lockbits/Dockerfile:1-47` — structure complète du Dockerfile

  **Critères d'acceptation**:

  ```
  Scénario: Vérifier que la ligne a été ajoutée au bon endroit
    Outil: Bash (grep)
    Préconditions: Fichier modifié
    Étapes:
      1. grep -n "lockbits_start" site_lockbits/Dockerfile
    Résultat attendu: La ligne existe APRÈS "COPY" et AVANT "chown". Ligne avec "RUN date +%s > /var/www/html/.lockbits_start"
    Preuve: .sisyphus/evidence/task-2-dockerfile.txt

  Scénario: Vérifier que le Dockerfile est toujours syntaxiquement valide
    Outil: Bash
    Préconditions: Fichier modifié
    Étapes:
      1. grep -c "FROM" site_lockbits/Dockerfile  # Attendu: 1
      2. grep -c "COPY" site_lockbits/Dockerfile   # Attendu: ≥1
      3. grep -c "CMD" site_lockbits/Dockerfile    # Attendu: ≥1
    Résultat attendu: Tous les éléments essentiels présents, structure intacte
    Preuve: .sisyphus/evidence/task-2-dockerfile-valid.txt
  ```

  **Preuve à capturer**:
  - [ ] `task-2-dockerfile.txt`
  - [ ] `task-2-dockerfile-valid.txt`

  **Commit**: OUI (groupe avec 1, 3)
  - Message: `chore: add .lockbits_start marker for uptime tracking`
  - Fichiers: `site_lockbits/Dockerfile`

- [x] 3. Modifier `site_lockbits/.htaccess` — exclure `/metrics` des règles de réécriture

  **Quoi faire**:
  - Ajouter une RewriteRule de sécurité pour que `/metrics` soit servi directement sans réécriture
  - Insérer APRÈS `RewriteEngine On` (ligne 1) et AVANT `SetEnvIf` (ligne 4) :
    ```
    # Exclure /metrics des règles de réécriture (sécurité)
    RewriteRule ^metrics$ - [L]
    ```
  - Même si les règles actuelles ne ciblent que `/client/*`, cette règle explicite empêche toute réécriture future non intentionnelle de `/metrics`

  **Profil agent recommandé**:
  - **Catégorie**: `quick`
    - Raison: modification d'une ligne dans un fichier existant
  - **Compétences**: aucune

  **Parallélisation**:
  - **Parallélisable**: OUI
  - **Groupe**: Vague 1
  - **Bloque**: Aucune
  - **Bloqué par**: Aucune

  **Références**:
  - `site_lockbits/.htaccess:1-16` — fichier complet à modifier

  **Critères d'acceptation**:

  ```
  Scénario: Vérifier la règle d'exclusion
    Outil: Bash (grep)
    Préconditions: Fichier modifié
    Étapes:
      1. grep "RewriteRule ^metrics" site_lockbits/.htaccess
    Résultat attendu: La ligne "RewriteRule ^metrics$ - [L]" existe après RewriteEngine On
    Preuve: .sisyphus/evidence/task-3-htaccess.txt

  Scénario: Vérifier que les règles existantes sont intactes
    Outil: Bash (grep)
    Préconditions: Fichier modifié
    Étapes:
      1. grep "client" site_lockbits/.htaccess | grep -c "Rewrite"
    Résultat attendu: ≥2 (RewriteCond et RewriteRule pour /client/)
    Preuve: .sisyphus/evidence/task-3-htaccess-existing.txt
  ```

  **Preuve à capturer**:
  - [ ] `task-3-htaccess.txt`
  - [ ] `task-3-htaccess-existing.txt`

  **Commit**: OUI (groupe avec 1, 2)
  - Message: `chore: add safety RewriteCond for /metrics`
  - Fichiers: `site_lockbits/.htaccess`

- [x] 4. Modifier `docker-compose.preprod.yml` — ajouter réseau `monitoring` à `site-web`

  **Quoi faire**:
  - Ajouter `- monitoring` à la liste `networks:` du service `site-web` dans `docker-compose.preprod.yml`
  - Actuellement (lignes 141-143) :
    ```yaml
        networks:
          - frontend
    ```
  - Devenir :
    ```yaml
        networks:
          - frontend
          - monitoring
    ```
  - **Ne PAS** modifier les autres services, volumes, ou networks — seulement la section `site-web`

  **Profil agent recommandé**:
  - **Catégorie**: `quick`
  - **Compétences**: aucune

  **Parallélisation**:
  - **Parallélisable**: OUI
  - **Groupe**: Vague 2
  - **Bloque**: Aucune
  - **Bloqué par**: Aucune

  **Références**:
  - `docker-compose.preprod.yml:141-143` — section networks de site-web (emplacement exact)
  - `docker-compose.preprod.yml:63` — pattern existant : edr-server a déjà `- monitoring`

  **Critères d'acceptation**:

  ```
  Scénario: Vérifier que monitoring est ajouté à site-web
    Outil: Bash (grep avec contexte)
    Préconditions: Fichier modifié
    Étapes:
      1. grep -A5 "site-web:" docker-compose.preprod.yml | grep -A10 "networks:"
    Résultat attendu: Affiche "- frontend" suivi de "- monitoring"
    Preuve: .sisyphus/evidence/task-4-preprod-network.txt

  Scénario: Vérifier que le fichier YAML est valide
    Outil: Bash (python)
    Étapes:
      1. python3 -c "import yaml; yaml.safe_load(open('docker-compose.preprod.yml')); print('VALID')"
    Résultat attendu: "VALID"
    Preuve: .sisyphus/evidence/task-4-preprod-yaml.txt
  ```

  **Preuve à capturer**:
  - [ ] `task-4-preprod-network.txt`
  - [ ] `task-4-preprod-yaml.txt`

  **Commit**: OUI (groupe avec 5)
  - Message: `fix: add site-web to monitoring network (preprod)`
  - Fichiers: `docker-compose.preprod.yml`

- [x] 5. Modifier `docker-compose.prod.yml` — ajouter réseau `monitoring` à `site-web`

  **Quoi faire**:
  - Même modification que tâche 4 mais sur `docker-compose.prod.yml`
  - Ajouter `- monitoring` à la liste `networks:` du service `site-web` (lignes 141-143 du fichier prod)
  - Actuellement :
    ```yaml
        networks:
          - frontend
    ```
  - Devenir :
    ```yaml
        networks:
          - frontend
          - monitoring
    ```

  **Profil agent recommandé**:
  - **Catégorie**: `quick`
  - **Compétences**: aucune

  **Parallélisation**:
  - **Parallélisable**: OUI (parallèle avec tâche 4)
  - **Groupe**: Vague 2
  - **Bloque**: Aucune
  - **Bloqué par**: Aucune

  **Références**:
  - `docker-compose.prod.yml:141-143` — section networks de site-web
  - `docker-compose.prod.yml:63` — pattern edr-server avec monitoring

  **Critères d'acceptation**:

  ```
  Scénario: Vérifier monitoring ajouté à site-web (prod)
    Outil: Bash (grep)
    Étapes:
      1. grep -A5 "site-web:" docker-compose.prod.yml | grep -A10 "networks:"
    Résultat attendu: "- frontend" suivi de "- monitoring"
    Preuve: .sisyphus/evidence/task-5-prod-network.txt

  Scénario: Vérifier YAML valide (prod)
    Outil: Bash (python)
    Étapes:
      1. python3 -c "import yaml; yaml.safe_load(open('docker-compose.prod.yml')); print('VALID')"
    Résultat attendu: "VALID"
    Preuve: .sisyphus/evidence/task-5-prod-yaml.txt
  ```

  **Preuve à capturer**:
  - [ ] `task-5-prod-network.txt`
  - [ ] `task-5-prod-yaml.txt`

  **Commit**: OUI (groupe avec 4)
  - Message: `fix: add site-web to monitoring network (prod)`
  - Fichiers: `docker-compose.prod.yml`

- [x] 6. Modifier `docker/prometheus/prometheus.yml` — ajouter job `lockbits_site`

  **Quoi faire**:
  - Ajouter un nouveau job `lockbits_site` dans `scrape_configs` de `prometheus.yml`
  - Le fichier BASE (non préprod/prod) utilise les service names (pattern existant : `edr-server:8000`)
  - Donc target : `site-web:80` (port 80 = Apache interne)
  - Nouvelle section à ajouter après le job `prometheus` :
    ```yaml
      - job_name: "lockbits_site"
        metrics_path: "/metrics"
        static_configs:
          - targets: ["site-web:80"]
    ```
  - **Ne PAS toucher** aux jobs existants (`lockbits_edr`, `prometheus`)

  **Profil agent recommandé**:
  - **Catégorie**: `quick`
  - **Compétences**: aucune

  **Parallélisation**:
  - **Parallélisable**: OUI (parallèle avec 4, 5, 7, 8)
  - **Groupe**: Vague 2
  - **Bloque**: Aucune
  - **Bloqué par**: Aucune

  **Références**:
  - `docker/prometheus/prometheus.yml:5-13` — structure des scrape_configs existante
  - `docker/prometheus/prometheus.yml:6-9` — pattern à suivre (job `lockbits_edr`)

  **Critères d'acceptation**:

  ```
  Scénario: Vérifier job lockbits_site ajouté
    Outil: Bash
    Étapes:
      1. grep -A4 "lockbits_site" docker/prometheus/prometheus.yml
    Résultat attendu: Affiche job_name + metrics_path + targets avec site-web:80
    Preuve: .sisyphus/evidence/task-6-prometheus-base.txt

  Scénario: Vérifier YAML valide
    Outil: Python
    Étapes:
      1. python3 -c "import yaml; yaml.safe_load(open('docker/prometheus/prometheus.yml')); print('VALID')"
    Résultat attendu: "VALID"
    Preuve: .sisyphus/evidence/task-6-prometheus-base-yaml.txt
  ```

  **Preuve à capturer**:
  - [ ] `task-6-prometheus-base.txt`
  - [ ] `task-6-prometheus-base-yaml.txt`

  **Commit**: OUI (groupe avec 7, 8)
  - Message: `feat: add lockbits_site job to prometheus config (base)`
  - Fichiers: `docker/prometheus/prometheus.yml`

- [x] 7. Modifier `docker/prometheus/prometheus.preprod.yml` — ajouter job `lockbits_site`

  **Quoi faire**:
  - Ajouter job `lockbits_site` dans `scrape_configs` de `prometheus.preprod.yml`
  - La config preprod utilise les **container names** (pattern existant : `lockbits_edr_preprod:8000`)
  - Target : `lockbits_web_preprod:80` (container name + port 80 Apache)
  - Nouvelle section à ajouter après le job `prometheus` :
    ```yaml
      - job_name: "lockbits_site"
        metrics_path: "/metrics"
        static_configs:
          # Container name pour éviter round-robin Dokploy
          - targets: ["lockbits_web_preprod:80"]
    ```
  - S'inspirer du commentaire existant sur le job EDR qui explique pourquoi container name est utilisé

  **Profil agent recommandé**:
  - **Catégorie**: `quick`
  - **Compétences**: aucune

  **Parallélisation**:
  - **Parallélisable**: OUI
  - **Groupe**: Vague 2
  - **Bloque**: Aucune
  - **Bloqué par**: Aucune

  **Références**:
  - `docker/prometheus/prometheus.preprod.yml:5-17` — structure existante
  - `docker/prometheus/prometheus.preprod.yml:8-13` — pattern container name + commentaire

  **Critères d'acceptation**:

  ```
  Scénario: Vérifier job lockbits_site en preprod
    Outil: Bash
    Étapes:
      1. grep -A4 "lockbits_site" docker/prometheus/prometheus.preprod.yml
    Résultat attendu: Contient lockbits_web_preprod:80
    Preuve: .sisyphus/evidence/task-7-prometheus-preprod.txt

  Scénario: Vérifier YAML valide
    Outil: Python
    Étapes:
      1. python3 -c "import yaml; yaml.safe_load(open('docker/prometheus/prometheus.preprod.yml')); print('VALID')"
    Résultat attendu: "VALID"
    Preuve: .sisyphus/evidence/task-7-prometheus-preprod-yaml.txt
  ```

  **Preuve à capturer**:
  - [ ] `task-7-prometheus-preprod.txt`
  - [ ] `task-7-prometheus-preprod-yaml.txt`

  **Commit**: OUI (groupe avec 6, 8)
  - Message: `feat: add lockbits_site job to prometheus config (preprod)`
  - Fichiers: `docker/prometheus/prometheus.preprod.yml`

- [x] 8. Modifier `docker/prometheus/prometheus.prod.yml` — ajouter job `lockbits_site`

  **Quoi faire**:
  - Ajouter job `lockbits_site` dans `scrape_configs` de `prometheus.prod.yml`
  - Target : `lockbits_web:80` (container name prod)
  - Ajouter après le job `prometheus` :
    ```yaml
      - job_name: "lockbits_site"
        metrics_path: "/metrics"
        static_configs:
          # Container name pour éviter round-robin Dokploy
          - targets: ["lockbits_web:80"]
    ```

  **Profil agent recommandé**:
  - **Catégorie**: `quick`
  - **Compétences**: aucune

  **Parallélisation**:
  - **Parallélisable**: OUI
  - **Groupe**: Vague 2
  - **Bloque**: Aucune
  - **Bloqué par**: Aucune

  **Références**:
  - `docker/prometheus/prometheus.prod.yml:5-17` — structure existante
  - `docker/prometheus/prometheus.prod.yml:8-13` — pattern container name

  **Critères d'acceptation**:

  ```
  Scénario: Vérifier job lockbits_site en prod
    Outil: Bash
    Étapes:
      1. grep -A4 "lockbits_site" docker/prometheus/prometheus.prod.yml
    Résultat attendu: Contient lockbits_web:80
    Preuve: .sisyphus/evidence/task-8-prometheus-prod.txt

  Scénario: Vérifier YAML valide
    Outil: Python
    Étapes:
      1. python3 -c "import yaml; yaml.safe_load(open('docker/prometheus/prometheus.prod.yml')); print('VALID')"
    Résultat attendu: "VALID"
    Preuve: .sisyphus/evidence/task-8-prometheus-prod-yaml.txt
  ```

  **Preuve à capturer**:
  - [ ] `task-8-prometheus-prod.txt`
  - [ ] `task-8-prometheus-prod-yaml.txt`

  **Commit**: OUI (groupe avec 6, 7)
  - Message: `feat: add lockbits_site job to prometheus config (prod)`
  - Fichiers: `docker/prometheus/prometheus.prod.yml`

- [x] 9. Créer `docker/grafana/provisioning/dashboards/site-dashboard.json` — dashboard Grafana

  **Quoi faire**:
  - Créer un nouveau dashboard Grafana provisionné pour les métriques du site
  - Suivre EXACTEMENT le même format que `edr-dashboard.json` (même `__inputs`, même structure de templating)
  - UID du dashboard : `lockbits-site`
  - Titre : "LockBits Site"
  - Tags : `["site", "lockbits"]`
  - Panels à inclure :

    | Panel | Type | Métrique | Position |
    |---|---|---|---|
    | DB Health | stat | `lockbits_db_health` | x=0, y=1, w=3, h=4 |
    | Users Total | stat | `lockbits_users_total` | x=3, y=1, w=3, h=4 |
    | Tickets by Status | piechart | `lockbits_tickets_total` | x=6, y=1, w=6, h=8 |
    | PHP Memory | stat | `lockbits_php_memory_bytes` (unit: bytes) | x=12, y=1, w=4, h=4 |
    | HTTP Requests | stat | `lockbits_http_requests_total` | x=16, y=1, w=4, h=4 |
    | PHP Uptime | stat | `lockbits_php_uptime_seconds` (unit: s) | x=20, y=1, w=4, h=4 |
    | Requests (time series) | timeseries | `rate(lockbits_http_requests_total[5m])` | x=0, y=5, w=12, h=8 |

  - Copier le pattern `__inputs` de `edr-dashboard.json` pour la datasource Prometheus (uid `${datasource}`)
  - Réutiliser le style de mapping du panel DB Health (vert=healthy, rouge=down) depuis le panel EDR équivalent

  **Profil agent recommandé**:
  - **Catégorie**: `unspecified-low`
    - Raison: création d'un fichier JSON structuré suivant un template existant
  - **Compétences**: aucune

  **Parallélisation**:
  - **Parallélisable**: OUI (indépendant des tâches infra)
  - **Groupe**: Vague 2
  - **Bloque**: Aucune
  - **Bloqué par**: Aucune

  **Références**:
  - `docker/grafana/provisioning/dashboards/edr-dashboard.json:1-290` — template COMPLET à suivre (structure, __inputs, datasource, style de panels)
  - `docker/grafana/provisioning/dashboards/dashboards.yml:1-11` — config provisioning (détecte automatiquement les nouveaux fichiers JSON dans le dossier)
  - Formats des métriques Prometheus disponibles : `lockbits_db_health`, `lockbits_users_total`, `lockbits_tickets_total{status="..."}`, `lockbits_php_memory_bytes`, `lockbits_php_uptime_seconds`, `lockbits_http_requests_total`

  **Critères d'acceptation**:

  ```
  Scénario: Vérifier la structure du dashboard JSON
    Outil: Bash (python)
    Étapes:
      1. python3 -c "
    import json
    with open('docker/grafana/provisioning/dashboards/site-dashboard.json') as f:
        d = json.load(f)
    assert d['uid'] == 'lockbits-site', f'UID: {d[\"uid\"]}'
    assert d['title'] == 'LockBits Site', f'Title: {d[\"title\"]}'
    assert len(d['panels']) >= 5, f'Panels: {len(d[\"panels\"])}'
    assert '__inputs' in d, 'Missing __inputs'
    assert d['templating']['list'][0]['type'] == 'datasource', 'Missing datasource template'
    print(f'VALID: uid={d[\"uid\"]}, title={d[\"title\"]}, panels={len(d[\"panels\"])}')
    "
    Résultat attendu: "VALID: uid=lockbits-site, title=LockBits Site, panels=..." (pas d'erreur)
    Preuve: .sisyphus/evidence/task-9-dashboard-valid.txt

  Scénario: Vérifier que les métriques utilisées existent dans le plan
    Outil: Bash (grep)
    Étapes:
      1. grep -o 'lockbits_[a-z_]*' docker/grafana/provisioning/dashboards/site-dashboard.json | sort -u
    Résultat attendu: Les métriques du dashboard correspondent aux 6 métriques définies dans metrics.php
    Preuve: .sisyphus/evidence/task-9-dashboard-metrics.txt
  ```

  **Preuve à capturer**:
  - [ ] `task-9-dashboard-valid.txt`
  - [ ] `task-9-dashboard-metrics.txt`

  **Commit**: OUI
  - Message: `feat: add site dashboard (UID: lockbits-site) to Grafana`
  - Fichiers: `docker/grafana/provisioning/dashboards/site-dashboard.json`

- [x] 10. Modifier `tests/smoke_site.py` — ajouter vérification `/metrics`

  **Quoi faire**:
  - Ajouter une section de test après les tests existants (après le bloc "Protected pages" ligne 31-37) et avant le print final (ligne 39)
  - Nouveau bloc à insérer :
    ```python
    # ── Metrics endpoint ──────────────────────────────────────────────────
    r = s.get(f"{base}/metrics", timeout=TIMEOUT)
    assert r.status_code == 200, f"GET /metrics → {r.status_code}"
    assert "text/plain" in r.headers.get("content-type", ""), "/metrics not text/plain"
    body = r.text

    # Verify expected metric names
    expected_metrics = [
        "lockbits_db_health",
        "lockbits_users_total",
        'lockbits_tickets_total{status="open"}',
        'lockbits_tickets_total{status="in_progress"}',
        'lockbits_tickets_total{status="closed"}',
        "lockbits_php_memory_bytes",
        "lockbits_http_requests_total",
    ]
    for metric in expected_metrics:
        assert metric in body, f"Missing metric: {metric}"

    # Verify values are numeric
    import re
    for name in ("lockbits_db_health", "lockbits_users_total"):
        matches = re.findall(rf"{re.escape(name)}\s+([\d.]+)", body)
        assert len(matches) > 0, f"No value for {name}"
        float(matches[0])  # raises if not numeric

    # Verify HELP/TYPE lines present
    assert "# HELP" in body, "Missing HELP lines"
    assert "# TYPE" in body, "Missing TYPE lines"

    print("✓ GET /metrics  (Prometheus format, 6 metrics)")
    ```
  - L'assertion sur le Content-Type doit être flexible : `"text/plain" in ...` (peut contenir `version=0.0.4`)

  **Profil agent recommandé**:
  - **Catégorie**: `quick`
    - Raison: ajout d'un bloc de test dans un fichier Python existant
  - **Compétences**: aucune

  **Parallélisation**:
  - **Parallélisable**: NON (dépend de metrics.php pour être testable)
  - **Groupe**: Vague 2 (commence après vague 1)
  - **Bloque**: Aucune
  - **Bloqué par**: Tâche 1 (metrics.php)

  **Références**:
  - `tests/smoke_site.py:1-43` — fichier complet à modifier
  - `tests/smoke_site.py:14-18` — pattern de test existant pour s'inspirer

  **Critères d'acceptation**:

  ```
  Scénario: Vérifier que le fichier Python a une syntaxe valide
    Outil: Bash
    Étapes:
      1. python3 -c "import py_compile; py_compile.compile('tests/smoke_site.py', doraise=True); print('VALID')"
    Résultat attendu: "VALID"
    Preuve: .sisyphus/evidence/task-10-smoke-syntax.txt

  Scénario: Vérifier que les assertions de métriques sont présentes
    Outil: Bash (grep)
    Étapes:
      1. grep "lockbits_" tests/smoke_site.py
    Résultat attendu: Toutes les métriques attendues sont référencées (lockbits_db_health, lockbits_users_total, etc.)
    Preuve: .sisyphus/evidence/task-10-smoke-metrics.txt
  ```

  **Preuve à capturer**:
  - [ ] `task-10-smoke-syntax.txt`
  - [ ] `task-10-smoke-metrics.txt`

  **Commit**: OUI
  - Message: `test: add /metrics verification to smoke tests`
  - Fichiers: `tests/smoke_site.py`

---

## Vague de vérification finale (OBLIGATOIRE — après TOUTES les tâches d'implémentation)

> 4 agents de revue tournent en PARALLÈLE. Tous doivent APPROUVER. Présenter les résultats consolidés à l'utilisateur et obtenir un "ok" explicite avant de terminer.

- [x] F1. **Plan Compliance Audit** — `oracle`
  Lire le plan de bout en bout. Pour chaque "Doit inclure": vérifier que l'implémentation existe (lire le fichier, curl l'endpoint, exécuter la commande). Pour chaque "Ne doit PAS inclure": chercher dans le code les patterns interdits — rejeter avec fichier:ligne si trouvé. Vérifier que les fichiers de preuve existent dans `.sisyphus/evidence/`. Comparer les livrables avec le plan.
  Sortie: `Doit inclure [N/N] | Ne doit PAS [N/N] | Tâches [N/N] | VERDICT: APPROUVE/REJETTE`

- [x] F2. **Code Quality Review** — `unspecified-high`
  Lire tous les fichiers modifiés. Vérifier: `php -l` pour tout fichier PHP, `python3 -c "compile(...)"` pour tout fichier Python, validation YAML pour tout fichier YAML. Vérifier l'absence de: `as any`, commentaires excessifs, sur-abstraction, noms génériques (`data`/`result`/`item`/`temp`). Vérifier PSR-12 pour le PHP.
  Sortie: `PHP lint [PASS/FAIL] | Python syntax [PASS/FAIL] | YAML valid [PASS/FAIL] | Issues [N] | VERDICT`

- [x] F3. **Real Manual QA** — `unspecified-high`
  Partir d'un état propre. Exécuter CHAQUE scénario QA de CHAQUE tâche — suivre les étapes exactes, capturer les preuves. Tester l'intégration cross-tâche (les features fonctionnent ensemble, pas isolément). Vérifier les cas limites. Sauvegarder dans `.sisyphus/evidence/final-qa/`.
  Sortie: `Scénarios [N/N pass] | Intégration [N/N] | Cas limites [N testés] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `deep`
  Pour chaque tâche: lire "Quoi faire", lire le diff réel (`git diff` ou `git log`). Vérifier 1:1 — tout ce qui est dans le spec a été construit (rien d'oublié), rien au-delà du spec n'a été construit (pas de scope creep). Vérifier la conformité "Ne doit PAS inclure". Détecter la contamination cross-tâche (tâche N touchant les fichiers de tâche M).
  Sortie: `Tâches [N/N conformes] | Contamination [PROPRE/N problèmes] | VERDICT`

---

## Stratégie de commit

- **1**: `feat: add /metrics endpoint for Prometheus scraping` — metrics.php
- **2**: `chore: add .lockbits_start marker for uptime tracking` — Dockerfile
- **3**: `chore: add safety RewriteCond for /metrics` — .htaccess
- **4**: `fix: add site-web to monitoring network (preprod)` — compose preprod
- **5**: `fix: add site-web to monitoring network (prod)` — compose prod
- **6**: `feat: add lockbits_site job to prometheus config (base)` — prometheus.yml
- **7**: `feat: add lockbits_site job to prometheus config (preprod)` — prometheus.preprod.yml
- **8**: `feat: add lockbits_site job to prometheus config (prod)` — prometheus.prod.yml
- **9**: `feat: add site dashboard (UID: lockbits-site) to Grafana` — site-dashboard.json
- **10**: `test: add /metrics verification to smoke tests` — smoke_site.py

/Tous les commits: branche `feat/metrics-prometheus`, PR vers `develop`/
/Qui: tout groupe automatique/

---

## Critères de succès

### Commandes de vérification
```bash
# Vérifier que /metrics répond
curl -s http://localhost:8080/metrics | head -20

# Vérifier la config Prometheus
grep -c "lockbits_site" docker/prometheus/prometheus.yml    # Attendu: ≥1
grep -c "lockbits_site" docker/prometheus/prometheus.preprod.yml   # Attendu: ≥1
grep -c "lockbits_site" docker/prometheus/prometheus.prod.yml   # Attendu: ≥1

# Vérifier réseau monitoring dans les compose
grep -c "monitoring" docker-compose.preprod.yml   # Attendu: ≥2 (réseau + site-web)
grep -c "monitoring" docker-compose.prod.yml   # Attendu: ≥2

# Smoke tests
python tests/smoke_site.py http://localhost:8080
```

### Checklist finale
- [ ] Tous les "Doit inclure" présents
- [ ] Aucun "Ne doit PAS inclure" présent
- [ ] Tous les tests passent
- [ ] Evidence de QA dans `.sisyphus/evidence/`
- [ ] Dashboard Grafana provisionné avec UID correct
- [ ] Réseau monitoring ajouté aux deux compose
- [ ] Job Prometheus ajouté aux trois configs
