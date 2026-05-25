# Documentation LockBits

Bienvenue dans la documentation technique du projet LockBits. Ce repertoire centralise l'ensemble des informations necessaires au developpement, au deploiement et a l'exploitation de l'infrastructure.

LockBits est un projet scolaire de l'ESGI qui propose une solution de detection et de reponse sur les terminaux (EDR) associee a un portail client web. L'architecture repose sur deux composants principaux (un backend FastAPI et un site PHP/Apache) orchestres via Docker Compose.

## Structure de la documentation

### Architecture

- [architecture.md](architecture.md) : Vue d'ensemble de l'architecture, topologie reseau, fonctionnement des sous-modules, flux de donnees entre les composants.

### Deploiement

- [deployment/prod.md](deployment/prod.md) : Deploiement en production avec Docker Compose, images GHCR, Watchtower et gestion des secrets.
- [deployment/preprod.md](deployment/preprod.md) : Deploiement en pre-production avec les images `:develop`, variantes des noms de conteneurs et volumes.
- [deployment/install.md](deployment/install.md) : Documentation detaillee du script `install.sh`, ses modes et ses options.

### Developpement

- [development/setup.md](development/setup.md) : Configuration de l'environnement de developpement local, clone avec sous-modules, variables d'environnement, execution des tests.
- [development/git-workflow.md](development/git-workflow.md) : Strategie de branches, conventions de nommage, processus de pull requests.
- [development/ci-cd.md](development/ci-cd.md) : Pipeline CI/CD, etapes de test, build, push et scan de securite.

### Services

- [services/edr.md](services/edr.md) : Documentation du service EDR (FastAPI), ses endpoints, son authentification et son integration VirusTotal.
- [services/site.md](services/site.md) : Documentation du site PHP/Apache, sa base de donnees MySQL et son integration GLPI.

### Operations

- [ops/monitoring.md](ops/monitoring.md) : Metriques, logs et alerting avec Prometheus, Grafana, Loki et Watchtower.
- [ops/security.md](ops/security.md) : Bonnes pratiques de securite, gestion des secrets, CORS, rate limiting et scans Trivy.
- [ops/backup.md](ops/backup.md) : Sauvegarde des bases de donnees MySQL et PostgreSQL, politique de rotation et procedure de restauration.
