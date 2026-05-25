# Deploiement production

Cette page decrit la procedure de deploiement de la stack LockBits en environnement de production. Le deploiement ne necessite pas de cloner le depot Git : seuls Docker et le fichier `docker-compose.prod.yml` sont requis.

## Architecture de production

Le fichier `docker-compose.prod.yml` definit cinq services :

- **edr-server** : image `ghcr.io/lockbits-esgi/edr:latest`, expose le port 8001, connecte au reseau `frontend`.
- **site-web** : image `ghcr.io/lockbits-esgi/site_lockbits:latest`, expose le port 8080, connecte auxreseaux `frontend` et `backend`.
- **site-db** : image `mysql:8.0`, connectee au reseau `backend` uniquement, aucun port expose sur l'hote.
- **db-init** : service ephemeral qui initialise le schema de la base de donnees MySQL au premier demarrage.
- **watchtower** : image `nickfedor/watchtower`, verifie toutes les 5 minutes les nouvelles images et applique les mises a jour automatiquement.

Les conteneurs suivent la convention de nommage `lockbits_SERVICENAME` : `lockbits_edr`, `lockbits_web`, `lockbits_db`, `lockbits_watchtower`.

## Images GHCR

Les images sont hebergees sur le GitHub Container Registry :

- `ghcr.io/lockbits-esgi/edr:latest`
- `ghcr.io/lockbits-esgi/site_lockbits:latest`

Si les images sont privees, une authentification est necessaire :

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <github-username> --password-stdin
```

Le token doit avoir au minimum l'autorisation `read:packages` pour telecharger les images.

## Procedure de deploiement

### Installation rapide (recommande)

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash
```

Avec un token GHCR pour les images privees :

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | GITHUB_TOKEN=<token> bash
```

Le script telecharge les fichiers de configuration, cree le fichier `.env` depuis `.env.example`, vous invite a vous connecter a GHCR si un token est fourni, lance la stack, et verifie que les services repondent.

### Installation manuelle

```bash
# Telecharger les fichiers de configuration
curl -O https://raw.githubusercontent.com/Lockbits-ESGI/main/main/docker-compose.prod.yml
curl -O https://raw.githubusercontent.com/Lockbits-ESGI/main/main/.env.example

# Creer et editer le fichier d'environnement
cp .env.example .env
nano .env

# Lancer la stack
docker compose -f docker-compose.prod.yml up -d
```

### Verification

```bash
# Lister les conteneurs
docker compose -f docker-compose.prod.yml ps

# Tester l'API EDR
curl http://localhost:8001/health

# Tester le site web
curl http://localhost:8080/
```

## Secrets et variables d'environnement

Le fichier `.env` doit contenir toutes les variables requises. Les valeurs par defaut dans `docker-compose.prod.yml` sont intentionnellement laissees avec des mots de passe par defaut qui doivent etre changes avant tout deploiement en production.

Variables obligatoires a configurer :

- `EDR_AUTH_TOKEN` : token d'authentification pour l'API EDR (minimum 32 caracteres aleatoires).
- `DB_ROOT_PASSWORD` : mot de passe root de MySQL.
- `DB_PASS` : mot de passe de l'utilisateur applicatif MySQL.

Variables recommandees :

- `VT_API_KEY` : cle API VirusTotal pour l'analyse de fichiers.
- `GLPI_*` : configuration de l'integration GLPI si utilisee.
- `CORS_ORIGINS` : origines autorisees pour les requetes CORS (a restreindre en production).

## Mise a jour avec Watchtower

Watchtower est configure avec l'option `--interval 300` (verification toutes les 5 minutes) et `--cleanup` (suppression des anciennes images). Il surveille tous les conteneurs en cours d'execution sur le daemon Docker et redemarre automatiquement ceux dont l'image a ete mise a jour sur le registry.

Pour appliquer une mise a jour immediate sans attendre Watchtower :

```bash
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

Ou via le script d'installation :

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --update
```

## Limites de ressources

Les services ont des limites de ressources configurees :

- **edr-server** : 1 CPU, 512 Mo de memoire.
- **site-web** : 0.5 CPU, 256 Mo de memoire.
- **site-db** : 1 CPU, 1 Go de memoire.
