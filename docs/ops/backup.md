# Sauvegarde et restauration

LockBits fournit deux scripts dans le repertoire `scripts/` pour la sauvegarde et la restauration de l'ensemble des donnees et de la configuration. Cette page decrit leur fonctionnement, la politique de retention et les procedures de recuperation.

## Scripts disponibles

- `scripts/backup.sh` : cree une sauvegarde horodatee des bases de donnees, des volumes et des fichiers de configuration.
- `scripts/restore.sh` : restaure une sauvegarde existante de maniere interactive ou en ligne de commande.

## Composants sauvegardes

| Composant           | Conteneur           | Methode                    | Format         |
|---------------------|---------------------|----------------------------|----------------|
| MySQL (site)        | `lockbits_db`       | `docker exec` + mysqldump  | `.sql.gz`      |
| PostgreSQL (EDR)    | `lockbits_edr_db`   | `docker exec` + pg_dump    | `.sql.gz`      |
| Volume EDR          | `lockbits_edr`      | `docker cp` + tar (fallback si PostgreSQL absent) | `.tar.gz` |
| Configuration       | —                   | copie directe des fichiers | `.tar.gz`      |

Les fichiers de configuration sauvegardes incluent `.env`, tous les fichiers `docker-compose*.yml` et le `Caddyfile` s'il est present.

## Fonctionnement de backup.sh

### Utilisation

```bash
# Sauvegarde par defaut (dans ./backups/)
./scripts/backup.sh

# Repertoire personnalise
BACKUP_DIR=/mnt/nas/lockbits-backups ./scripts/backup.sh
```

### Processus

1. Le script charge les variables d'environnement depuis `.env` si le fichier existe.
2. Il verifie que Docker est disponible et que les conteneurs requis sont en cours d'execution.
3. Il effectue un dump de la base MySQL avec les options `--single-transaction`, `--routines`, `--triggers` et `--events` pour garantir la coherence des donnees.
4. Si le conteneur PostgreSQL `lockbits_edr_db` est en cours d'execution, il effectue un dump avec `pg_dump` et les options `--clean` et `--if-exists`.
5. Si PostgreSQL n'est pas disponible mais que le conteneur EDR est en cours d'execution, il sauvegarde le volume de donnees de l'EDR via `docker cp` et `tar`.
6. Il copie les fichiers de configuration dans une archive separee.
7. Il cree un fichier `MANIFEST.txt` contenant les metadonnees de la sauvegarde (horodatage, nom d'hote, version Docker, identifiants de base de donnees utilises).
8. Il supprime les sauvegardes plus anciennes que 7 jours (politique de retention).

### Retention

La retention est fixee a 7 jours par defaut (`RETENTION_DAYS=7` dans le script). Les sauvegardes sont stockees dans des dossiers horodates au format `YYYY-MM-DD_HHMMSS`. Seules les 7 dernieres sauvegardes quotidiennes sont conservees.

La retention peut etre ajustee en modifiant la variable `RETENTION_DAYS` dans le script.

### Planification recommandee

Ajoutez une entree crontab pour une sauvegarde quotidienne :

```bash
0 2 * * * cd /opt/lockbits && ./scripts/backup.sh >> /opt/lockbits/backups/backup.log 2>&1
```

## Fonctionnement de restore.sh

### Utilisation

```bash
# Mode interactif : liste les sauvegardes et demande laquelle restaurer
./scripts/restore.sh

# Restaurer une sauvegarde specifique par horodatage
./scripts/restore.sh 2025-05-25_143022

# Restaurer depuis un chemin complet
./scripts/restore.sh /mnt/nas/lockbits-backups/2025-05-25_143022
```

### Processus

1. En mode interactif, le script liste les sauvegardes disponibles dans `BACKUP_DIR`.
2. Il valide le contenu de la sauvegarde selectionnee (verification de la presence du manifeste, des dumps et des archives).
3. Il demande une confirmation avant d'appliquer la restauration (operation irreversible).
4. Il restaure MySQL en decompressant le dump et en l'injectant via `mysql` CLI.
5. Il restaure PostgreSQL de la meme maniere via `psql`.
6. Il restaure le volume de donnees EDR si present dans la sauvegarde.
7. Il restaure les fichiers de configuration avec une confirmation individuelle pour chaque fichier.

### Precautions

- La restauration ecrase les donnees existantes. Une confirmation explicite est requise avant chaque operation.
- Les fichiers de configuration sont restaures un par un avec demande de confirmation.
- Les conteneurs de base de donnees doivent etre en cours d'execution pour la restauration.
- Le script ne redefinit pas les permissions ou les mots de passe. Apres une restauration, verifiez que les acces sont fonctionnels.

## Scenarios de recuperation

### Corruption de la base MySQL

```bash
# 1. Arreter le serveur web pour empecher les ecritures
docker stop lockbits_web

# 2. Lister et selectionner une sauvegarde
./scripts/restore.sh

# 3. Redemarrer le serveur web
docker start lockbits_web
```

### Recuperation complete d'un serveur

```bash
# 1. Deployer une nouvelle stack
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash

# 2. Copier la sauvegarde sur le nouveau serveur
scp -r backups/2025-05-25_143022 user@new-server:/opt/lockbits/backups/

# 3. Restaurer l'integralite des donnees
cd /opt/lockbits
./scripts/restore.sh 2025-05-25_143022

# 4. Redemarrer les services
docker restart lockbits_web lockbits_edr
```

### Suppression accidentelle de donnees

```bash
# 1. Arreter immediatement les conteneurs qui ecrivent dans la base
docker stop lockbits_web

# 2. Restaurer uniquement la base de donnees concernee
./scripts/restore.sh 2025-05-25_143022

# 3. Redemarrer les services
docker start lockbits_web
```

### Restauration partielle (fichiers de configuration seulement)

Executez `restore.sh` et declinez les restaurations de base de donnees pour ne restaurer que les fichiers de configuration. Chaque fichier est demande individuellement.

## Securite des sauvegardes

- Les sauvegardes contiennent le fichier `.env` avec les mots de passe et tokens. Le repertoire de sauvegarde doit etre protege (par exemple `chmod 700 backups/`).
- Pour les copies hors site, chiffrez les archives avant transfert.
- Les identifiants de base de donnees sont lus depuis `.env` et ne sont pas stockes dans les scripts.
