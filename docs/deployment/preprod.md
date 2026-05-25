# Deploiement pre-production

L'environnement de pre-production permet de valider les changements avant leur passage en production. Il utilise les memes fichiers de configuration que la production, mais avec des images taggees `:develop` et des noms de conteneurs distincts pour eviter les conflits.

## Differences avec la production

| Aspect              | Production                        | Pre-production                     |
|---------------------|-----------------------------------|------------------------------------|
| Images              | `:latest`                         | `:develop`                         |
| Conteneurs          | `lockbits_edr`, `lockbits_web`    | `lockbits_edr_preprod`, `lockbits_web_preprod` |
| Base de donnees     | `lockbits_db`                     | `lockbits_db_preprod`              |
| Volume MySQL        | `mysql_data`                      | `mysql_data_preprod`               |
| Volume EDR          | `edr_data`                        | `edr_data_preprod`                 |
| Watchtower          | `lockbits_watchtower`             | `lockbits_watchtower_preprod`      |
| APP_ENV             | `production`                      | `staging`                          |
| APP_NAME            | `LockBits Client Area`            | `LockBits Client Area (Preprod)`   |

## Fichier de configuration

Le fichier `docker-compose.preprod.yml` suit exactement la meme structure que la version production avec les ajustements ci-dessus. Il peut etre execute cote a cote avec la stack de production sur le meme hote sans conflit, puisque les noms de conteneurs, les volumes et les reseaux sont differents.

## Utilisation avec install.sh

```bash
# Installation preprod
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --env=preprod

# Mise a jour de la preprod
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --env=preprod --update

# Mise a jour automatique pour la preprod
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --env=preprod --cron
```

L'option `--env=preprod` modifie le comportement du script `install.sh` pour telecharger `docker-compose.preprod.yml` au lieu de `docker-compose.prod.yml`. Les fichiers de configuration preprod et prod peuvent coexister dans le meme repertoire.

## Pipeline de pre-production

Le flux de travail vers la pre-production suit ce chemin :

1. Un developpeur pousse une branche `feature/*` et cree une pull request vers `develop`.
2. La CI execute les tests, puis build et push les images avec le tag `:develop` sur GHCR.
3. Watchtower en pre-production detecte la nouvelle image `:develop` et redemarre les conteneurs automatiquement.

Ce processus permet de valider les changements dans un environnement identique a la production avant le merge vers `main`.

## Utilisation manuelle

```bash
# Telecharger le fichier compose preprod
curl -O https://raw.githubusercontent.com/Lockbits-ESGI/main/main/docker-compose.preprod.yml

# Lancer la stack preprod
docker compose -f docker-compose.preprod.yml up -d

# Verifier
curl http://localhost:8001/health
curl http://localhost:8080/
```

## Limitations

- Les images `:develop` sont reconstruites a chaque push sur la branche `develop`. Il n'y a pas de gestion de version semantique pour ce tag.
- La base de donnees preprod est independante de la base de production. Les donnees ne sont pas synchronisees entre les deux environnements.
- Il est recommande d'utiliser un hote different pour la preprod si les ressources le permettent, mais le fichier compose est concu pour la cohabitation sur un meme hote.
