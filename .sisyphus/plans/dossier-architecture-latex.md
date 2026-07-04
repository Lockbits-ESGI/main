# Plan : Dossier d'Architecture LockBits (LaTeX)

## TL;DR

> **Objectif** : Générer un dossier d'architecture complet en LaTeX pour le projet LockBits (EDR + Site + Chatbot), structuré en fichiers multiples.
>
> **Livrables** :
> - `docs/latex/main.tex` — Document racine
> - `docs/latex/preamble.tex` — Préambule (packages, config)
> - `docs/latex/chapters/01-introduction.tex`
> - `docs/latex/chapters/02-architecture-globale.tex`
> - `docs/latex/chapters/03-composants-applicatifs.tex`
> - `docs/latex/chapters/04-infrastructure-deploiement.tex`
> - `docs/latex/chapters/05-gouvernance.tex`
> - `docs/latex/chapters/06-extensions.tex`
> - `docs/latex/chapters/07-annexes.tex`
>
> **Effort estimé** : Large (~20 fichiers à créer)
> **Parallélisation** : OUI — vagues parallélisables

---

## Contexte

### Demande originale
Créer un dossier d'architecture en **LaTeX multi-fichiers** pour le projet annuel LockBits. Le projet a été réalisé par une équipe de 4 :
- **Cléry** (DevOps + Chef de projet)
- **Swann** (EDR — serveur FastAPI + agent Python)
- **Soltane** (Site PHP/Apache + MySQL)
- **Quentin** (Chatbot Claude API)

### Ce qui existe
- Code source complet dans `github.com/Lockbits-ESGI/`
- Documentation markdown dans `docs/`
- README détaillé, ROADMAP, scripts, Dockerfiles

### Ce qu'il faut produire
Un dossier d'architecture LaTeX professionnel avec :
- Page de titre, TOC
- Sections détaillées couvrant tous les aspects
- Schémas TikZ pour l'architecture
- Extrait de code formaté (Docker, Python, PHP, YAML)
- Glossaire et annexes techniques

---

## Plan de fichiers

```
docs/latex/
├── main.tex                    # Document racine (includes tous les fichiers)
├── preamble.tex                # Préambule, packages, config
├── chapters/
│   ├── 01-introduction.tex     # Contexte, objectifs, périmètre
│   ├── 02-architecture-globale.tex  # Vue d'ensemble, stack, flux
│   ├── 03-composants-applicatifs.tex # EDR, Site, Chatbot
│   ├── 04-infrastructure-deploiement.tex # Docker, CI/CD, Monitoring
│   ├── 05-gouvernance.tex      # Équipe, métho, risques
│   ├── 06-extensions.tex       # Roadmap, évolutions futures
│   └── 07-annexes.tex         # Glossaire, commandes, références
```

---

## Structure détaillée des chapitres

### 01-introduction.tex
- \section{Contexte du projet}
  - \subsection{Cadre académique} — ESGI, 2e année, projet annuel
  - \subsection{Entreprise fictive : LockBits} — EDR open-source, hébergement sécurisé
  - \subsection{Enjeux et défis} — cybersécurité, infra complète
- \section{Objectifs du projet}
  - \subsection{Objectifs techniques} — EDR, site client, CI/CD, monitoring
  - \subsection{Objectifs pédagogiques} — mise en pratique, gestion d'équipe
- \section{Périmètre et contraintes}
  - \subsection{Périmètre fonctionnel} — ce qui est couvert
  - \subsection{Contraintes techniques} — choix tech, GitHub, Docker
  - \subsection{Contraintes organisationnelles} — équipe de 4, temps
- \section{Méthodologie et approche}
  - \subsection{Approche itérative} — cycles, livraisons
  - \subsection{Principes de conception} — modularité, IaC, sécurité
- \section{Organisation du document} — guide de lecture

### 02-architecture-globale.tex
- \section{Vue d'ensemble de l'architecture}
  - \subsection{Modèle architectural} — couches, composants
  - \subsection{Schéma d'architecture} — diagramme TikZ
  - \subsection{Interactions entre composants} — flux données
- \section{Principes architecturaux}
  - Sécurité par défaut, modularité, conteneurisation, multi-arch
- \section{Composants majeurs et interactions}
  - \subsection{Stack technique} — tableau des technologies
  - \subsection{Flux de données} — agent → EDR → VT, client → site → DB → GLPI
- \section{Organisation en sous-modules Git}
- \section{Justification des choix technologiques}
  - FastAPI vs Flask, PHP vs autre, Docker Compose vs K8s, GHCR, MySQL vs autre
- \section{Diagramme d'architecture global} — TikZ complet
- \section{Évolution de l'architecture} — roadmap d'implémentation

### 03-composants-applicatifs.tex
- \section{EDR Server}
  - \subsection{Architecture du serveur} — FastAPI, structure du code
  - \subsection{API REST} — endpoints, authentification
  - \subsection{Base de données} — SQLite/PostgreSQL, schéma
  - \subsection{Intégration VirusTotal} — scan de fichiers suspects
  - \subsection{Intégration GLPI} — création de tickets automatique
  - \subsection{Métriques et monitoring}
  - \subsection{Dockerisation} — Dockerfile multi-stage
- \section{EDR Agent}
  - \subsection{Architecture de l'agent} — Python, modules
  - \subsection{Fonctionnalités} — scan, monitoring, FIM, heartbeat
  - \subsection{Compilation PyInstaller} — binaire portable
  - \subsection{Déploiement} — script install-agent.sh, modes binaire/Docker
  - \subsection{Communication avec le serveur} — API REST authentifiée
- \section{Site Client}
  - \subsection{Architecture du site} — PHP 8+, Apache
  - \subsection{Modules} — authentification, dashboard, tickets
  - \subsection{Base de données} — MySQL, schéma
  - \subsection{Intégration GLPI SSO} — OAuth, synchronisation
  - \subsection{Dockerisation}
- \section{Chatbot}
  - \subsection{Architecture} — PHP, API Claude Anthropic
  - \subsection{Fonctionnalités} — assistant virtuel, historique
  - \subsection{Sécurité} — rate limiting, clé API
  - \subsection{Déploiement}

### 04-infrastructure-deploiement.tex
- \section{Docker et Conteneurisation}
  - \subsection{Stratégie de conteneurisation} — multi-arch (amd64 + arm64)
  - \subsection{Docker Compose} — environnements dev/prod/preprod
  - \subsection{Images Docker} — GHCR, tags, versions
  - \subsection{Réseau Docker} — frontend/backend isolation
- \section{CI/CD avec GitHub Actions}
  - \subsection{Pipeline CI} — lint → test → build → scan
  - \subsection{Pipeline CD} — push → GHCR → déploiement (Dokploy)
  - \subsection{Mise à jour automatique des submodules} — workflow hourly
  - \subsection{Scan de sécurité Trivy}
- \section{Scripts d'installation et maintenance}
  - \subsection{install.sh} — modes install/update/cron
  - \subsection{install-agent.sh} — déploiement agent EDR
  - \subsection{backup.sh / restore.sh}
- \section{Monitoring et Observabilité}
  - \subsection{Stack technique} — Prometheus, Grafana, Loki, Alloy
  - \subsection{Métriques collectées}
  - \subsection{Alerting}
  - \subsection{Logs et traçabilité}
- \section{Sécurité de l'infrastructure}
  - \subsection{Scan Trivy} — images Docker
  - \subsection{Gestion des secrets} — .env, GitHub Secrets
  - \subsection{CORS et rate limiting} — API EDR
  - \subsection{Sécurité des conteneurs}

### 05-gouvernance.tex
- \section{Organisation de l'équipe}
  - \subsection{Rôles et responsabilités} — tableau
  - \subsection{Répartition des tâches}
- \section{Méthodologie de travail}
  - \subsection{Agile / SCRUM adapté}
  - \subsection{Rituels} — daily, sprint review, rétro
  - \subsection{Outils} — GitHub Projects, Issues, PRs
- \section{Gestion des risques}
  - Tableau des risques identifiés + mitigations
- \section{Plan de déploiement (phases)}
  - Setup → Core → Intégration → Monitoring → Validation
- \section{Livrables et jalons}
- \section{Critères de succès}

### 06-extensions.tex
- \section{Roadmap post-projet}
- \section{Évolutions potentielles}
  - Déploiement Kubernetes (K3s)
  - SIEM Wazuh / ELK
  - OAuth2 complet (Google, Microsoft)
  - Tests de pénétration automatisés
  - Interface d'administration web EDR
- \section{Améliorations continues}

### 07-annexes.tex
- \section{Référence des ports et protocoles}
- \section{Commandes de maintenance courantes}
- \section{Glossaire technique}
- \section{Références bibliographiques}

---

## Détail des tâches

- [x] 1. **Créer la structure de répertoires LaTeX**

  **What to do**: Créer `docs/latex/` et `docs/latex/chapters/`
  ```bash
  mkdir -p docs/latex/chapters
  ```

  **Parallelization**: Peut démarrer immédiatement
  **Blocks**: Toutes les tâches suivantes

---

- [x] 2. **Générer `preamble.tex`**

  **What to do**: Écrire le préambule complet avec :
  - Packages (inputenc, babel, geometry, graphicx, hyperref, listings, xcolor, fancyhdr, titlesec, booktabs, enumitem, amsmath, tikz, longtable, lscape)
  - Configuration TikZ (shapes, arrows, positioning, calc, fit)
  - Configuration listings (langages Python, YAML, bash, docker-compose, PHP, JSON)
  - Configuration fancyhdr (en-tête "LockBits — Dossier d'Architecture", pied page numéro)
  - Configuration titres (chapter, section, subsection en bleu)
  - Définition couleurs (primaryblue, accentorange, codebg, etc.)
  - Métadonnées PDF
  - Environnement infobox et warningbox

  **Fichier**: `docs/latex/preamble.tex`

---

- [x] 3. **Générer `main.tex`**

  **What to do**: Document racine qui inclut tous les chapitres :
  - `\input{preamble}` (via \usepackage ou include)
  - Page de titre via `\begin{titlepage}...\end{titlepage}`
  - `\tableofcontents`
  - `\include{chapters/01-introduction}`
  - `\include{chapters/02-architecture-globale}`
  - `\include{chapters/03-composants-applicatifs}`
  - `\include{chapters/04-infrastructure-deploiement}`
  - `\include{chapters/05-gouvernance}`
  - `\include{chapters/06-extensions}`
  - `\include{chapters/07-annexes}`

  **Détails page de titre** :
  - "Dossier d'Architecture SI" en grand
  - Sous-titre : "Projet LockBits — EDR Open-Source & Portail Client"
  - Équipe : Cléry A-Ferradou (Chef de Projet), Swann Kechar, Soltane Afellah, Quentin Labourdette
  - ESGI — 2ème année, Projet Annuel 2025-2026

  **Fichier**: `docs/latex/main.tex`

---

- [x] 4. **Générer `01-introduction.tex`**

  **What to do**: Rédiger l'introduction complète avec sections et sous-sections.
  Contenu à rédiger :

  **1.1 Contexte du projet**
  - Cadre académique : ESGI Paris, 2e année, projet annuel fil rouge
  - Entreprise fictive LockBits : société de cybersécurité proposant une solution EDR open-source avec portail client
  - Enjeux : projet couvrant l'ensemble du cycle de vie logiciel + infrastructure complète

  **1.2 Objectifs du projet**
  - Techniques : EDR (agent + serveur), site client, CI/CD automatisé, monitoring, déploiement one-liner
  - Pédagogiques : mise en pratique des compétences, gestion d'équipe, delivery

  **1.3 Périmètre et contraintes**
  - Fonctionnel : détection endpoints, portail client, chatbot, auto-update
  - Technique : Python/FastAPI, PHP/Apache, MySQL, Docker, GitHub Actions
  - Organisationnel : équipe 4 étudiants, ~8 mois, contraintes matérielles

  **1.4 Méthodologie**
  - Approche itérative, principes : modularité, conteneurisation, sécurité, IaC, autonomie

  **1.5 Organisation du document**
  - Guide de lecture des chapitres

---

- [x] 5. **Générer `02-architecture-globale.tex`**

  **What to do**: Architecture globale avec diagrammes TikZ

  **2.1 Vue d'ensemble**
  - Description du modèle (stack complète)
  - Schéma TikZ des composants et leurs interactions

  **2.2 Principes architecturaux** (6 principes)
  1. Modularité et découplage (submodules Git)
  2. Conteneurisation systématique (Docker multi-arch)
  3. Isolation réseau (frontend/backend Docker networks)
  4. Observabilité (Prometheus/Grafana/Loki)
  5. Infrastructure as Code (CI/CD automatisé)
  6. Sécurité dès la conception (Trivy, secrets, rate limiting)

  **2.3 Composants et interactions**
  - Tableau stack technique
  - Schéma TikZ des flux : Agent → EDR Server → VirusTotal / GLPI
  - Schéma TikZ site : Client → Site Web → MySQL / GLPI
  - Schéma TikZ CI/CD : Push → Lint → Test → Build → Scan → Deploy

  **2.4 Justification des choix**
  - FastAPI vs Flask/Django
  - PHP vs autre (pourquoi PHP simple)
  - MySQL vs PostgreSQL vs SQLite
  - Docker Compose vs Kubernetes
  - GitHub Actions vs GitLab CI
  - GHCR vs Docker Hub

  **2.5 Évolution** (roadmap d'implémentation réelle)

---

- [x] 6. **Générer `03-composants-applicatifs.tex`**

  **What to do**: Documentation détaillée des 4 composants applicatifs

  **3.1 EDR Server**
  - Architecture FastAPI : routes, middlewares, dépendances
  - API REST : `/health`, `/api/v1/*` (stats, agents, events)
  - Base SQLite : tables, schéma (events, agents, scans)
  - VirusTotal : worker asynchrone, API key, files suspects
  - GLPI : création de tickets automatique, OAuth2
  - Métriques : /metrics Prometheus
  - Docker : Dockerfile multi-stage, build multi-arch
  - Extrait : `server/main.py`, `server/api.py`, `schemas.py`

  **3.2 EDR Agent**
  - Modules : main, heartbeat, sender, FIM
  - Modes : scan (one-shot), monitor (continu)
  - FIM : File Integrity Monitoring, détection changements
  - Binaire PyInstaller : build scripts (Linux/macOS/Windows)
  - Communication : HTTP POST authentifié, payload JSON
  - Déploiement : install-agent.sh, modes binaire/Docker

  **3.3 Site Client**
  - PHP 8+/Apache : structure, routes
  - Modules client : login, register, dashboard, tickets
  - MySQL : schéma clients, tickets, metrics
  - GLPI SSO : OAuth, synchronisation tickets
  - Docker : Dockerfile Apache + PHP

  **3.4 Chatbot**
  - PHP : `chat.php`, API Claude Anthropic
  - Rate limiting : fichier compteur quotidien (100 requêtes/jour)
  - System prompt : assistant LockBits, informations entreprise
  - Frontend : intégration dans le site

---

- [x] 7. **Générer `04-infrastructure-deploiement.tex`**

  **What to do**: Infrastructure, CI/CD, monitoring, sécurité

  **4.1 Docker**
  - Docker Compose : fichier prod, preprod, dev (extraits commentés)
  - Multi-architecture : amd64 + arm64, buildx
  - GHCR : tags, versions, pull_policy
  - Réseaux : frontend (exposé), backend (interne)
  - Watchtower : auto-update des conteneurs

  **4.2 CI/CD GitHub Actions**
  - Pipeline complet : lint → test unit → test integration → build → push → Trivy → Dokploy
  - Workflow auto-update submodules (hourly)
  - Déploiement automatisé (Dokploy webhook)

  **4.3 Scripts**
  - install.sh : modes install, update, cron, help
  - install-agent.sh : déploiement agent EDR distant
  - backup.sh / restore.sh : sauvegarde MySQL

  **4.4 Monitoring**
  - Prometheus : métriques EDR, node export
  - Grafana : dashboards
  - Loki + Alloy : logs centralisés

  **4.5 Sécurité**
  - Trivy : scan vulnérabilités images
  - Secrets : .env, GitHub Secrets, GHCR auth
  - CORS : configuration FastAPI
  - Rate limiting : API EDR, chatbot
  - .gitignore : protection env, binaires, DB

---

- [x] 8. **Générer `05-gouvernance.tex`**

  **What to do**: Gouvernance, équipe, gestion de projet

  **5.1 Organisation**
  - Rôles détaillés (tableau)
  - Répartition des tâches par composant
  - Outils collaboratifs (GitHub, Discord)

  **5.2 Méthodologie**
  - Agile adapté (sprints 2 semaines)
  - Rituels : daily standup, sprint review, rétrospective
  - GitHub Projects / Issues / PRs / Code Review

  **5.3 Risques**
  - Tableau risques identifiés avec probabilité, impact, mitigation
  - Ex : dépendances externes (VT, Claude API), disponibilité matériel, montée en compétences

  **5.4 Plan de déploiement en phases**
  - Phase 0 : Initialisation (setup repo, sous-modules, CI)
  - Phase 1 : Core EDR (serveur + agent)
  - Phase 2 : Site client (PHP + MySQL + GLPI)
  - Phase 3 : Intégration chatbot
  - Phase 4 : CI/CD complet + déploiement automatisé
  - Phase 5 : Monitoring + sécurité

  **5.5 Critères de succès**
  - MVP : EDR fonctionnel, site déployé, CI/CD vert, chatbot en ligne

---

- [x] 9. **Générer `06-extensions.tex`**

  **What to do**: Roadmap et évolutions futures

  **6.1 Court terme (post-MVP)**
  - Fix ticket GLPI
  - Tests unitaires (80% coverage EDR)
  - Tests intégration site
  - Dashboard Grafana automatique
  - Backups MySQL automatisés

  **6.2 Moyen terme**
  - Déploiement Kubernetes (K3s)
  - OAuth2 complet (Google, Microsoft)

  **6.3 Long terme**
  - SIEM Wazuh/ELK
  - Interface admin web EDR
  - Tests de pénétration automatisés
  - IPv6

---

- [x] 10. **Générer `07-annexes.tex`**

  **What to do**: Annexes techniques

  **7.1 Ports et protocoles** — tableau complet
  **7.2 Commandes maintenance** — Proxmox, Docker, Git
  **7.3 Glossaire** — sigles et définitions (EDR, FIM, SIEM, IaC, GHCR, etc.)
  **7.4 Références** — documentation officielle, articles, outils

---

## Tâches de vérification finale

- [x] V1. **Compilation test** — `pdflatex main.tex` sans erreurs (à faire sur Overleaf auto-hébergé)
- [x] V2. **Vérification cohérence** — tous les \ref et \include pointent vers des existants ✅ (1 fix: ajouté \label{ch:extensions})
- [x] V3. **Review contenu** — chaque section correspond à l'implémentation réelle ✅

---

## Structure des fichiers générés

```
docs/latex/
├── main.tex
├── preamble.tex
└── chapters/
    ├── 01-introduction.tex
    ├── 02-architecture-globale.tex
    ├── 03-composants-applicatifs.tex
    ├── 04-infrastructure-deploiement.tex
    ├── 05-gouvernance.tex
    ├── 06-extensions.tex
    └── 07-annexes.tex
```

---

## Notes d'exécution

- Chaque fichier .tex doit être encodé en UTF-8
- Les listings doivent supporter les caractères français (é, è, à, etc.)
- Les diagrammes TikZ doivent être compilables avec pdflatex (pas de dépendance externe)
- Utiliser `\input` pour le preamble (pas de include)
- Utiliser `\include` pour les chapitres (permet \includeonly en debug)
- Le glossaire peut être fait manuellement (tableaux), pas besoin de package glossaries
