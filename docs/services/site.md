# Service Site (PHP/Apache)

Le site LockBits est l'interface web du projet. Il est developpe en PHP et servi via un serveur Apache integre dans l'image Docker. Il permet la gestion des clients, l'affichage des informations de ticketing et l'administration du parc.

## Architecture

Le code source se trouve dans le sous-module `site_lockbits/` du depot principal. L'image Docker est construite a partir du Dockerfile present a la racine du sous-module.

Le site est deploye dans un conteneur Apache avec PHP. La configuration PHP est ajustable via la variable d'environnement `PHP_MEMORY_LIMIT` (par defaut : 256 Mo).

L'initialisation de la base de donnees est automatique : au premier demarrage, le service `db-init` execute le script SQL `client/database.sql` pour creer les tables necessaires. Ce script est idempotent et peut etre execute plusieurs fois sans effet de bord.

## Base de donnees MySQL

Le site utilise une base de donnees MySQL 8.0 pour stocker les donnees des clients, les tickets, les configurations et les sessions.

### Configuration

La connexion a la base de donnees est configuree via des variables d'environnement :

```env
DB_HOST=site-db
DB_PORT=3306
DB_NAME=lockbits_client
DB_USER=lockbits
DB_PASS=<mot_de_passe_securise>
```

En developpement, la base de donnees est initialisee automatiquement via un volume monte dans le repertoire `/docker-entrypoint-initdb.d/` du conteneur MySQL (voir le fichier `docker-compose.yml`). En production et pre-production, l'initialisation est effectuee par le service `db-init`.

### Schema

Le schema de la base de donnees est defini dans `site_lockbits/client/database.sql`. Il contient les tables pour :

- Les clients et leurs informations.
- Les tickets de support.
- Les sessions utilisateur.
- Les configurations de l'application.

### Port

En developpement, le port MySQL est expose sur l'hote via `DB_EXPOSE_PORT=3307` pour permettre la connexion avec des outils externes (phpMyAdmin, MySQL Workbench). En production, aucun port MySQL n'est expose sur l'hote.

## Integration GLPI

Le site peut s'interfacer avec une instance GLPI (Gestion Libre de Parc Informatique) via son API REST. Cette integration permet de synchroniser les donnees de ticketing et de parc entre le site LockBits et GLPI.

Variables necessaires a l'integration GLPI :

| Variable                | Description                            |
|-------------------------|----------------------------------------|
| `GLPI_API_URL`          | URL de l'API REST GLPI                 |
| `GLPI_WEB_URL`          | URL de l'interface web GLPI            |
| `GLPI_APP_TOKEN`        | Token d'application GLPI               |
| `GLPI_USER_TOKEN`       | Token utilisateur GLPI                 |
| `GLPI_OAUTH_CLIENT_ID`  | Identifiant client OAuth               |
| `GLPI_OAUTH_CLIENT_SECRET` | Secret client OAuth                 |
| `GLPI_API_USERNAME`     | Nom d'utilisateur pour l'API           |
| `GLPI_API_PASSWORD`     | Mot de passe pour l'API                |

L'integration supporte deux modes d'authentification :
- **Token-based** : via `GLPI_APP_TOKEN` et `GLPI_USER_TOKEN`.
- **OAuth2** : via `GLPI_OAUTH_CLIENT_ID` et `GLPI_OAUTH_CLIENT_SECRET`.
- **Basic Auth** : via `GLPI_API_USERNAME` et `GLPI_API_PASSWORD`.

## Variables d'environnement

Toutes les variables du site sont definies dans le fichier `.env` :

| Variable             | Description                   | Valeur par defaut            |
|----------------------|-------------------------------|------------------------------|
| `WEB_PORT`           | Port d'exposition du site     | `8080`                       |
| `APP_NAME`           | Nom de l'application          | `LockBits Client Area`       |
| `APP_ENV`            | Environnement (`production`, `staging`, `testing`) | `production` |
| `DB_HOST`            | Hote MySQL                    | `site-db`                    |
| `DB_PORT`            | Port MySQL                    | `3306`                       |
| `DB_NAME`            | Nom de la base de donnees     | `lockbits_client`            |
| `DB_USER`            | Utilisateur MySQL             | `lockbits`                   |
| `DB_PASS`            | Mot de passe MySQL            | `lockbits_password`          |
| `PHP_MEMORY_LIMIT`   | Limite memoire PHP            | `256M`                       |

## Service db-init

Le service `db-init` est un conteneur ephemeral qui initialise le schema de la base de donnees. Il utilise l'image `site_lockbits` car elle contient le client MySQL et le fichier `database.sql`. Son execution est sequentielle :

1. Attente que MySQL soit sain (healthcheck).
2. Pause de 3 secondes pour stabilisation.
3. Execution du script SQL via `mysql` CLI.
4. Arret du conteneur (restart: "no").

En production, la connexion MySQL utilise `--ssl-mode=DISABLED` car la communication est securisee par l'isolation du reseau `backend`.

## Healthcheck

Le site web dispose d'un healthcheck Docker qui verifie toutes les 30 secondes que le serveur HTTP repond sur le port 80. Le conteneur est considere comme sain quand la page d'accueil retourne un code HTTP 200.
