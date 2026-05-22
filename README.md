# LockBits — Repo Principal

Repo d'orchestration qui regroupe tous les composants LockBits via git submodules et publie les images Docker sur [ghcr.io](https://ghcr.io/lockbits-esgi).

## Composants

| Service | Submodule | Image GHCR |
|---------|-----------|------------|
| EDR Server (FastAPI) | `edr/` | `ghcr.io/lockbits-esgi/edr:latest` |
| Site LockBits (PHP/Apache) | `site_lockbits/` | `ghcr.io/lockbits-esgi/site_lockbits:latest` |
| MySQL | — | `mysql:8.0` |

## Démarrage rapide

```bash
# 1. Cloner avec les submodules
git clone --recurse-submodules git@github.com:Lockbits-ESGI/main.git
cd main

# 2. Configurer l'environnement
cp .env.example .env
# Editer .env selon vos besoins

# 3. Lancer tous les services
docker compose up -d

# Vérifier les logs
docker compose logs -f
```

## Services exposés

| Service | URL par défaut |
|---------|---------------|
| EDR API | http://localhost:8000 |
| Site LockBits | http://localhost:8080 |
| MySQL | localhost:3307 |

## CI/CD

Le workflow `.github/workflows/build-and-push.yml` se déclenche sur chaque push sur `main` et :
- Build les images `edr` et `site_lockbits` en `linux/amd64` + `linux/arm64`
- Les publie sur `ghcr.io/lockbits-esgi/`
- Génère des attestations de provenance

## Mise à jour des submodules

```bash
git submodule update --remote --merge
```
