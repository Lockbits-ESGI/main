# Script install.sh

Le script `install.sh` est le point d'entree unique pour deployer, mettre a jour et gerer la stack LockBits. Il est concu pour fonctionner sans clone du depot Git, en telechargeant les fichiers necessaires directement depuis GitHub.

## Utilisation de base

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash
```

Cette commande telecharge les fichiers de configuration, cree le fichier `.env`, tente de se connecter a GHCR, lance la stack de production, et verifie le bon fonctionnement des services.

## Modes et options

### `--update` (ou `-u`)

Met a jour la stack existante sans telecharger les fichiers de configuration depuis zero.

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --update
```

Ce mode telecharge a nouveau les fichiers de configuration pour recuperer les versions les plus recentes, detecte les nouvelles variables d'environnement dans `.env.example` qui ne sont pas encore dans le `.env` existant (et les liste sans les appliquer automatiquement), puis redemarre la stack avec les dernieres images.

Si des nouvelles variables sont detectees, le script affiche un avertissement et laisse l'operateur les ajouter manuellement dans `.env`.

### `--cron`

Active la mise a jour automatique via crontab.

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --cron
```

Par defaut, le script ajoute une entree crontab qui execute la commande `--update` toutes les 5 minutes. L'intervalle est configurable avec `--interval` :

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --cron --interval=10
```

Le cron utilise un marqueur `# LOCKBITS_AUTO_UPDATE` pour identifier et gerer ses propres entrees. Les logs de mise a jour sont stockes dans `update.log` dans le repertoire d'installation.

### `--no-cron`

Desactive la mise a jour automatique en supprimant l'entree crontab marquee.

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --no-cron
```

### `--env`

Selectionne l'environnement de deploiement. Valeurs acceptees : `prod` (defaut) ou `preprod`.

```bash
# Deploiement pre-production
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --env=preprod

# Deploiement production (explicite)
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --env=prod
```

Cette option determine quel fichier Docker Compose est telecharge et utilise :

- `prod` : telecharge et utilise `docker-compose.prod.yml` (images `:latest`).
- `preprod` : telecharge et utilise `docker-compose.preprod.yml` (images `:develop`).

### `--update-sources`

Met a jour les references des sous-modules Git et declenche la CI.

```bash
bash install.sh --update-sources
```

Ce mode est different des autres : il s'execute depuis un clone local du depot Git (pas depuis un serveur distant). Il execute `git submodule update --remote --merge` sur chaque sous-module, verifie si des changements sont presents, cree un commit `"update submodules to latest"`, et propose de pousser sur `origin/main`.

Apres le push, la pipeline CI rebuild automatiquement les images sur GHCR. Une fois les images rebuildees, le serveur peut etre mis a jour avec `--update`.

**Attention** : ce mode est interactif et demande confirmation avant de pousser.

### `--help`

Affiche l'aide detaillee avec tous les modes et options disponibles.

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --help
```

## Variables d'environnement

Le script utilise deux variables d'environnement pour la configuration :

- `GITHUB_TOKEN` : token GitHub avec les droits `read:packages` pour s'authentifier aupres de GHCR et telecharger les images privees.
- `LOCKBITS_DIR` : repertoire d'installation. Par defaut, le script utilise le repertoire courant.

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | GITHUB_TOKEN=<token> LOCKBITS_DIR=/opt/lockbits bash
```

## Comportement detaille

1. Le script commence par verifier la presence de Docker et Docker Compose (uniquement en mode `install`).
2. Il determine le fichier compose en fonction de `--env`.
3. Il telecharge le fichier compose et `.env.example` depuis la branche `main` du depot.
4. En mode `update`, il compare `.env.example` avec le `.env` existant et liste les nouvelles variables.
5. En mode `install`, il cree `.env` depuis `.env.example` et tente la connexion GHCR.
6. Il execute `docker compose -f <fichier> up -d` pour lancer la stack.
7. Il attend jusqu'a 24 secondes que les services demarrent, puis verifie les endpoints `/health` (EDR) et `/` (site web).

## Notes importantes

- Le script est concu pour etre re-execute sans effet de bord. Il n'ecrase pas un `.env` existant en mode `update`.
- Les mots de passe par defaut dans `.env.example` doivent etre changes apres la premiere installation.
- Le mode `--cron` ajoute une entree crontab qui execute le script en mode non-interactif. Assurez-vous que les variables d'environnement necessaires sont accessibles dans le contexte cron.
