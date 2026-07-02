# Changelog

Toutes les modifications notables du projet LockBits.

> Format basé sur [Keep a Changelog](https://keepachangelog.com/),
> et [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2025-02-xx

### Ajouté

- **Repository d'orchestration** avec git submodules pour `edr` et `site_lockbits`
- **Docker Compose multi-environnement** : dev, prod, preprod
- **CI/CD GitHub Actions** : lint → test → build & push → Trivy scan
- **EDR Server (FastAPI)** : scan de fichiers avec intégration VirusTotal, rapports STIX
- **Agent EDR** : binaire portable + image Docker (linux/amd64 + arm64)
- **Site client PHP 8+/Apache** : portail client avec authentification GLPI SSO
- **Script d'installation one-liner** (`install.sh`) avec mode update et cron
- **Monitoring** : Prometheus, Grafana, Loki, Alloy
- **Dependabot** : dépendances pip, Docker, GitHub Actions
- **Pre-commit hooks** : ruff lint/format, validation basique

### Sécurité

- Authentification par token pour l'API EDR
- Healthchecks Docker pour tous les services
- Images multi-arch (amd64 + arm64)
- Scan Trivy en CI (CRITICAL + HIGH)

[1.0.0]: https://github.com/Lockbits-ESGI/main/releases/tag/v1.0.0
