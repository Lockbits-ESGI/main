# Contribuer à LockBits

Merci de vouloir contribuer à LockBits ! 🎉

Ce document vous guide à travers le processus de contribution.

## Table des matières

1. [Code de conduite](#code-de-conduite)
2. [Structure du projet](#structure-du-projet)
3. [Premiers pas](#premiers-pas)
4. [Workflow de développement](#workflow-de-développement)
5. [Conventions de code](#conventions-de-code)
6. [Tests](#tests)
7. [CI/CD](#cicd)
8. [Créer une Pull Request](#créer-une-pull-request)
9. [Signaler un bug](#signaler-un-bug)

## Code de conduite

Ce projet suit un [Code de Conduite](CODE_OF_CONDUCT.md) que tous les contributeurs doivent respecter.

## Structure du projet

```
LockBits-main/
├── edr/                  # Backend EDR (FastAPI/Python)
│   ├── server/           # API server
│   ├── client/           # Agent EDR
│   ├── packaging/        # Scripts de build
│   └── tests/            # Tests (pytest)
├── site_lockbits/        # Site web client (PHP/Apache)
│   ├── client/           # Application PHP
│   └── docs/             # Documentation
├── .github/workflows/    # CI/CD GitHub Actions
├── docker-compose.yml    # Dev stack
├── docker-compose.prod.yml # Prod stack
└── install.sh            # One-liner deploy
```

## Premiers pas

### Prérequis

- Docker & Docker Compose
- Git
- (Optionnel) Python 3.12+ pour le développement EDR
- (Optionnel) PHP 8.2+ pour le développement site

### Setup local

```bash
# Cloner avec les submodules
git clone --recurse-submodules git@github.com:Lockbits-ESGI/main.git
cd main

# Configurer l'environnement
cp .env.example .env

# Lancer la stack
docker compose up -d

# Vérifier
curl http://localhost:8001/health
curl http://localhost:8080/
```

## Workflow de développement

1. **Créer une branche** : `git checkout -b feat/ma-feature` ou `fix/mon-bug`
2. **Développer** dans les sous-modules concernés (`edr/` ou `site_lockbits/`)
3. **Tester** localement
4. **Commit** avec un message clair
5. **Push** et créer une Pull Request sur `main`

### Nommage des branches

| Type | Exemple |
|------|---------|
| Feature | `feat/authentification-2fa` |
| Fix | `fix/cors-prod` |
| Refactor | `refactor/docker-multi-stage` |
| Docs | `docs/securite` |
| CI | `ci/security-scan` |

## Conventions de code

### Python (EDR)

- Style : [PEP 8](https://peps.python.org/pep-0008/)
- Formatage : [Black](https://github.com/psf/black)
- Imports : [isort](https://pycqa.github.io/isort/)
- Typing : Annotations de type partout
- Linting : `ruff check .`

### PHP (Site)

- Style : [PSR-12](https://www.php-fig.org/psr/psr-12/)
- Pas de tags fermants `?>` en fin de fichier PHP
- Échapper toutes les sorties HTML (`htmlspecialchars`)
- Requêtes préparées pour SQL (via PDO ou MySQLi)

### Git

- Messages de commit en anglais ou français (impératif)
- Exemple : `feat: add rate limiting on /api/v1/scan`
- Exemple : `fix: restrict CORS origins in production`
- Un commit = une modification logique

## Tests

### EDR (Python)

```bash
cd edr
source venv/bin/activate

# Tests unitaires
pytest tests/ -v

# Tests avec couverture
pytest tests/ --cov=server -v
```

### Site (PHP)

Les tests du site sont effectués via smoke tests dans la CI.

## CI/CD

Le workflow CI est défini dans `.github/workflows/build-and-push.yml` :

```
test-edr-unit → test-edr-integration → build-edr (GHCR)
test-site-smoke ──────────────────────→ build-site (GHCR)
```

- Les tests sont exécutés sur chaque push
- Les images Docker sont publiées sur `ghcr.io/lockbits-esgi/*`
- Multi-arch : `linux/amd64` + `linux/arm64`

## Créer une Pull Request

1. Assurez-vous que les tests passent
2. Mettez à jour la documentation si nécessaire
3. Créez la PR vers `main`
4. Décrivez clairement les changements
5. Liez l'issue correspondante (ex: `Closes #42`)

### Template de PR

```markdown
## Description
Brève description des changements.

## Contexte
Pourquoi ce changement est nécessaire.

## Changements
- [ ] Correction de bug
- [ ] Nouvelle fonctionnalité
- [ ] Changement cassant (breaking)
- [ ] Documentation

## Tests
- [ ] Tests unitaires passent
- [ ] Tests intégration passent
- [ ] Testé manuellement

## Issues liées
Fixes #...
```

## Signaler un bug

Créez une [issue GitHub](https://github.com/Lockbits-ESGI/main/issues/new) avec :

- **Titre clair** : résumé du problème
- **Étapes pour reproduire** : actions menant au bug
- **Comportement attendu** : ce qui devrait se passer
- **Comportement actuel** : ce qui se passe
- **Environnement** : OS, Docker, navigateur, etc.
- **Logs/Capture d'écran** : si pertinent

## Licence

En contribuant, vous acceptez que vos contributions soient sous la même licence que le projet.
