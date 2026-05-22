# LockBits — Repo Principal

Repo d'orchestration qui regroupe tous les composants LockBits via git submodules et publie les images Docker sur [ghcr.io](https://ghcr.io/lockbits-esgi).

## Composants

| Service | Image GHCR | Port |
|---------|-----------|------|
| EDR Server (FastAPI) | `ghcr.io/lockbits-esgi/edr:latest` | 8000 |
| Site LockBits (PHP/Apache) | `ghcr.io/lockbits-esgi/site_lockbits:latest` | 8080 |
| MySQL | `mysql:8.0` | 3307 |

---

## Déploiement distant (images GHCR)

Aucun clone du repo nécessaire. Seuls Docker et les deux fichiers ci-dessous suffisent.

### 1. Récupérer les fichiers de config

```bash
curl -O https://raw.githubusercontent.com/Lockbits-ESGI/main/main/docker-compose.prod.yml
curl -O https://raw.githubusercontent.com/Lockbits-ESGI/main/main/.env.example
cp .env.example .env
# Editer .env avec les vraies valeurs
```

### 2. Se connecter à GHCR (images privées)

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <github-username> --password-stdin
```

### 3. Déployer

```bash
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

### 4. Initialiser la base de données (première installation uniquement)

```bash
curl -s https://raw.githubusercontent.com/Lockbits-ESGI/site_lockbits/main/client/database.sql \
  | docker exec -i lockbits_db mysql -u lockbits -plockbits_password lockbits_client
```

### 5. Vérifier

```bash
docker compose -f docker-compose.prod.yml ps
curl http://localhost:8000/health   # EDR → {"status":"ok","db_ok":true}
curl http://localhost:8080/         # Site → 200 OK
```

### Mettre à jour vers la dernière image

```bash
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

---

## docker run (services indépendants)

### EDR Server seul

```bash
docker run -d \
  --name lockbits_edr \
  -p 8000:8000 \
  -e DATABASE_URL=sqlite:///./miniedr.db \
  -e VT_ENABLED=false \
  -v edr_data:/app/data \
  ghcr.io/lockbits-esgi/edr:latest
```

Avec VirusTotal et token d'auth :

```bash
docker run -d \
  --name lockbits_edr \
  -p 8000:8000 \
  -e DATABASE_URL=sqlite:///./miniedr.db \
  -e VT_ENABLED=true \
  -e VT_API_KEY=<votre_clé_vt> \
  -e AUTH_TOKEN=<token_secret> \
  -v edr_data:/app/data \
  ghcr.io/lockbits-esgi/edr:latest
```

### Site LockBits seul (nécessite MySQL)

```bash
# 1. MySQL
docker run -d \
  --name lockbits_db \
  --network lockbits_network \
  -e MYSQL_ROOT_PASSWORD=root_password \
  -e MYSQL_DATABASE=lockbits_client \
  -e MYSQL_USER=lockbits \
  -e MYSQL_PASSWORD=lockbits_password \
  -v mysql_data:/var/lib/mysql \
  mysql:8.0

# 2. Site
docker run -d \
  --name lockbits_web \
  --network lockbits_network \
  -p 8080:80 \
  -e DB_HOST=lockbits_db \
  -e DB_NAME=lockbits_client \
  -e DB_USER=lockbits \
  -e DB_PASS=lockbits_password \
  ghcr.io/lockbits-esgi/site_lockbits:latest
```

---

## Développement local (build depuis les sources)

```bash
git clone --recurse-submodules git@github.com:Lockbits-ESGI/main.git
cd main
cp .env.example .env
docker compose up -d        # build + run
docker compose logs -f
```

---

## CI/CD

Le workflow `.github/workflows/build-and-push.yml` se déclenche sur chaque push sur `main` :

```
test-edr-unit ──> test-edr-integration ──> build-edr (ghcr.io/lockbits-esgi/edr:latest)
test-site-smoke ─────────────────────────> build-site (ghcr.io/lockbits-esgi/site_lockbits:latest)
```

Les images sont publiées en `linux/amd64` + `linux/arm64`.

## Mise à jour des submodules

```bash
git submodule update --remote --merge
```
