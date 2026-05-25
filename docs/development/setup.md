# Configuration de l'environnement de developpement

Ce guide decrit les etapes pour configurer un environnement de developpement local pour LockBits.

## Pre-requis

- Docker et Docker Compose (version plugin `docker compose` recommandee)
- Git
- (Optionnel) Python 3.12+ pour le developpement du serveur EDR
- (Optionnel) PHP 8.2+ pour le developpement du site web

## Clone du depot

Le depot principal utilise des sous-modules Git pour referencer les deux composants du projet. Le clone doit etre fait avec l'option `--recurse-submodules` pour recuperer automatiquement le code source de l'EDR et du site.

```bash
git clone --recurse-submodules git@github.com:Lockbits-ESGI/main.git
cd main
```

Si vous avez deja clone le depot sans les sous-modules :

```bash
git submodule update --init --recursive
```

Les sous-modules sont definis dans `.gitmodules` et pointent vers :

- `edr` : https://github.com/Lockbits-ESGI/edr.git
- `site_lockbits` : https://github.com/Lockbits-ESGI/site_lockbits.git

## Configuration de l'environnement

Copiez le fichier d'exemple et ajustez les valeurs :

```bash
cp .env.example .env
```

Les variables importantes pour le developpement local :

- `EDR_PORT=8000` : port du serveur EDR (8000 par defaut en dev).
- `EDR_AUTH_TOKEN=` : laissez vide pour le developpement, l'authentification est desactivee.
- `VT_ENABLED=false` : desactive VirusTotal en dev pour eviter les appels API.
- `CORS_ORIGINS=*` : autorise toutes les origines en dev.
- `LOG_LEVEL=DEBUG` : passez en mode debug pour des logs plus detailles.
- `DB_EXPOSE_PORT=3307` : expose MySQL sur le port 3307 pour les outils externes.

## Lancement de la stack de developpement

Le fichier `docker-compose.yml` est configure pour construire les images depuis les sources :

```bash
docker compose up -d
```

Cette commande construit les images localement en utilisant les Dockerfiles respectifs de chaque sous-module, puis lance les trois services (EDR, site web, MySQL). Les modifications du code source dans les sous-modules sont prises en compte apres un rebuild :

```bash
docker compose build
docker compose up -d
```

Pour suivre les logs en temps reel :

```bash
docker compose logs -f
```

## Verification

```bash
# Endpoint de sante de l'EDR
curl http://localhost:8000/health

# Page d'accueil du site web
curl http://localhost:8080/
```

## Execution des tests

### Tests EDR (Python)

Les tests unitaires du composant EDR utilisent `pytest`. Ils peuvent etre executes directement depuis le sous-module `edr/` :

```bash
cd edr

# Creer un environnement virtuel (premiere fois)
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Lancer les tests
pytest tests/ -v --tb=short

# Avec couverture
pytest tests/ --cov=server -v
```

En CI, les tests sont executes avec une base de donnees SQLite en memoire (`DATABASE_URL=sqlite:///:memory:`).

### Tests du site web

Les tests du site PHP sont des tests de smoke (fumee) qui verifient que le serveur web repond correctement et que les pages principales s'affichent sans erreur. Ils sont definis dans `tests/smoke_site.py` au niveau du depot principal.

Pour les executer localement, lancez d'abord la stack de developpement, puis :

```bash
pip install requests
python tests/smoke_site.py http://localhost:8080
```

## Structure du repertoire de developpement

```
LockBits-main/
├── edr/                    # Backend EDR (FastAPI/Python)
│   ├── server/             # API server
│   ├── client/             # Agent EDR
│   ├── packaging/          # Scripts de build
│   └── tests/              # Tests (pytest)
├── site_lockbits/          # Site web client (PHP/Apache)
│   ├── client/             # Application PHP
│   └── docs/               # Documentation du site
├── docker/
│   └── edr/                # Dockerfile pour l'EDR
├── tests/                  # Tests de smoke au niveau du repo principal
├── docker-compose.yml      # Stack de developpement
└── .env.example            # Modele de configuration
```
