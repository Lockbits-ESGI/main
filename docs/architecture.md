# Architecture de LockBits

## Vue d'ensemble

LockBits est compose de deux services distincts qui communiquent via une base de donnees MySQL partagee et un reseau interne Docker. Le projet suit une architecture modulaire ou chaque composant est developpe, versionne et conteneurise independamment.

Les deux composants principaux sont :

- **EDR** : Un serveur backend ecrit en Python avec le framework FastAPI. Il expose une API REST pour la gestion des agents de detection sur les terminaux. Son code source se trouve dans le sous-module `edr/`.
- **Site LockBits** : Une application web PHP hebergee sur Apache. Elle fournit l'interface client, la gestion des tickets et l'authentification. Son code source se trouve dans le sous-module `site_lockbits/`.

Le projet est heberge sur GitHub sous l'organisation [Lockbits-ESGI](https://github.com/Lockbits-ESGI). Les images Docker sont publiees sur le GitHub Container Registry (GHCR) a l'adresse `ghcr.io/lockbits-esgi/`.

## Topologie reseau

Le deploiement utilise deux reseaux Docker distincts pour isoler les services exposes du public de ceux qui sont internes.

```
                    ┌─────────────┐
                    │  Internet   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  Reverse    │
                    │  Proxy (TLS)│
                    └──┬───────┬──┘
                       │       │
              ┌────────▼───┐ ┌─▼───────────┐
              │  EDR Server │ │  Site Web   │
              │  :8001      │ │  :8080      │
              │  (FastAPI)  │ │  (PHP/Apache)│
              └─────────────┘ └───┬─────────┘
                  reseau frontend │
                                  │
                          ┌───────▼────────┐
                          │  MySQL (site-db)│
                          │  :3306          │
                          └────────────────┘
                          reseau backend
```

- **Reseau frontend** : accessible depuis l'exterieur. Les services EDR et Site Web y sont connectes et exposent leurs ports respectifs (8001 et 8080).
- **Reseau backend** : isole et non expose sur l'hote. Seuls le Site Web et la base de donnees MySQL y sont connectes. La base de donnees n'est jamais accessible directement depuis l'exterieur.

Cette separation garantit qu'une compromission du frontend ne donne pas un acces direct a la couche de donnees.

## Fonctionnement des sous-modules

Le depot principal (`Lockbits-ESGI/main`) est un depot d'orchestration. Il ne contient pas le code des services directement, mais les reference via des sous-modules Git.

```ini
[submodule "edr"]
    path = edr
    url = https://github.com/Lockbits-ESGI/edr.git

[submodule "site_lockbits"]
    path = site_lockbits
    url = https://github.com/Lockbits-ESGI/site_lockbits.git
```

Chaque sous-module pointe vers un commit specifique du depot distant. Quand un developpeur pousse du code sur `edr` ou `site_lockbits`, le depot principal ne voit pas le changement jusqu'a ce que la reference du sous-module soit mise a jour.

Deux mecanismes permettent de synchroniser ces references :

1. **Automatique** : un workflow GitHub Actions (`auto-update-submodules.yml`) s'execute toutes les heures, verifie si les sous-modules ont de nouveaux commits sur leur branche par defaut, et met a jour la reference si necessaire.
2. **Manuel** : la commande `bash install.sh --update-sources` met a jour tous les sous-modules, cree un commit de mise a jour et pousse sur `main`.

Apres la mise a jour des references, la pipeline CI rebuild automatiquement les images Docker avec le nouveau code.

## Flux de donnees

1. Un agent EDR installe sur un terminal envoie des donnees de scan et de monitoring a l'API EDR via des requetes HTTP authentifiees par le token `AUTH_TOKEN`.
2. Le serveur EDR traite les donnees, les stocke dans sa base (SQLite en developpement, PostgreSQL en production) et peut interroger l'API VirusTotal pour enrichir l'analyse des fichiers suspects.
3. Le site web PHP lit et ecrit dans la base de donnees MySQL pour gerer les clients, les tickets et les configurations.
4. Le site web peut egalement interroger une instance GLPI externe via son API REST pour synchroniser les donnees de ticketing et de parc informatique.

## Stack technique

| Composant       | Technologie         | Sous-module        | Port    |
|-----------------|---------------------|--------------------|---------|
| Serveur EDR     | Python / FastAPI    | `edr/`             | 8001    |
| Site web        | PHP 8+ / Apache     | `site_lockbits/`   | 8080    |
| Base de donnees | MySQL 8.0           | —                  | 3307    |
| CI/CD           | GitHub Actions      | —                  | —       |
| Registry        | GHCR                | —                  | —       |
| Mise a jour     | Watchtower          | —                  | —       |

Les images Docker sont construites en multi-architecture (`linux/amd64` et `linux/arm64`) pour supporter les environments x86 et ARM.

## Fichiers de configuration

Le repertoire principal contient plusieurs fichiers Docker Compose pour les differents environnements :

- `docker-compose.yml` : developpement local avec build depuis les sources.
- `docker-compose.prod.yml` : deploiement production avec images `:latest` depuis GHCR.
- `docker-compose.preprod.yml` : deploiement pre-production avec images `:develop` depuis GHCR.
- `.env.example` : modele de configuration avec toutes les variables d'environnement documentees.
- `install.sh` : script de deploiement automatique avec detection de l'environnement.
