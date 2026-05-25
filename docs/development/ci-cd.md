# Pipeline CI/CD

Le pipeline d'integration et de deploiement continu de LockBits est defini dans deux fichiers de workflow GitHub Actions. Il execute les tests, construit les images Docker, les publie sur GHCR et analyse les vulnerabilites.

## Workflow principal : build-and-push.yml

Ce workflow se declenche sur trois evenements :

| Evenement          | Tests | Build & Push | Tag GHCR  |
|--------------------|-------|--------------|-----------|
| Push sur `main`    | Oui   | Oui          | `:latest` |
| Push sur `develop` | Oui   | Oui          | `:develop`|
| PR vers `main`/`develop` | Oui | Non          | —         |

### Etapes du pipeline

```
test-edr-unit ──→ test-edr-integration ──→ build-edr ──┐
test-site-smoke ────────────────────────→ build-site ───┤
                                                        ↓
                                                 trivy-scan
```

#### Etape 1 : Tests

**test-edr-unit** : Execute les tests unitaires du composant EDR avec `pytest`. Utilise Python 3.12 avec mise en cache des dependances pip. Les tests sont executes avec une base de donnees SQLite en memoire et VirusTotal desactive.

**test-edr-integration** : Construit l'image Docker de l'EDR, lance un conteneur, attend qu'il soit pret (via le endpoint `/health`), puis execute les tests de smoke definis dans `tests/smoke_edr.py`. Cette etape depend du succes des tests unitaires.

**test-site-smoke** : Lance un conteneur MySQL, charge le schema de base de donnees depuis `site_lockbits/client/database.sql`, construit l'image du site, lance le conteneur sur un reseau dedie, attend qu'il soit pret, puis execute les tests de smoke dans `tests/smoke_site.py`.

#### Etape 2 : Build et Push

**build-edr** et **build-site** : Ces jobs s'executent uniquement sur les pushes (pas sur les pull requests). Ils utilisent `docker/build-push-action@v6` pour construire et publier les images sur GHCR.

Caracteristiques du build :

- **Multi-architecture** : les images sont construites pour `linux/amd64` et `linux/arm64` simultanement.
- **Cache** : utilisation du cache GitHub Actions (`type=gha`) avec mode `max` pour accelerer les builds suivants.
- **Tags** : le tag `:latest` est applique uniquement sur la branche par defaut (`main`). Le tag `:develop` est applique sur la branche `develop`. Les tags semantiques sont generes automatiquement si presents.
- **Provenance** : desactivee (`provenance: false`) pour eviter les meta-donnees `docker-provenance` qui ne sont pas necessaires.

#### Etape 3 : Scan de securite

**trivy-scan** : Apres la publication des images, Trivy analyse les vulnerabilites des images `:latest` :

- Scan des vulnerabilites CRITICAL et HIGH uniquement.
- Analyse des paquets OS et des bibliotheques applicatives.
- Mode rapport seulement (`exit-code: 0`) : les resultats sont affiches mais n'echeouent pas le pipeline.

## Workflow auto-update-submodules.yml

Ce workflow automatise la mise a jour des references des sous-modules.

### Declenchement

- Planifie toutes les heures via cron (`0 * * * *`).
- Declenchable manuellement depuis l'interface GitHub (`workflow_dispatch`).

### Fonctionnement

1. Le workflow clone le depot avec les sous-modules en mode recursif.
2. Il execute `git submodule update --remote --merge` pour recuperer les derniers commits de chaque sous-module.
3. Il verifie si des changements sont presents via `git diff --quiet`.
4. Si des changements sont detectes, il cree un commit automatique (`chore: auto-update submodules`) et le pousse sur `main`.

Ce commit declenche a son tour le workflow `build-and-push.yml`, qui rebuild les images avec le nouveau code.

### Gestion des conflits

Si les mises a jour automatiques des sous-modules entrainent des conflits (par exemple, si un commit a ete pousse manuellement entre-temps), le workflow echoue et une intervention manuelle est necessaire via `install.sh --update-sources`.

## Dependabot

Le fichier `.github/dependabot.yml` configure la mise a jour automatique des dependances :

| Ecosysteme       | Directory           | Frequence      |
|------------------|---------------------|----------------|
| pip (EDR)        | `/edr`              | Hebdomadaire   |
| Docker (EDR)     | `/docker/edr`       | Hebdomadaire   |
| Docker (Site)    | `/site_lockbits`    | Hebdomadaire   |
| GitHub Actions   | `/`                 | Hebdomadaire   |

## Images publiees

Les images sont publiees sur `ghcr.io/lockbits-esgi/` :

- `ghcr.io/lockbits-esgi/edr:latest` (production)
- `ghcr.io/lockbits-esgi/edr:develop` (pre-production)
- `ghcr.io/lockbits-esgi/site_lockbits:latest` (production)
- `ghcr.io/lockbits-esgi/site_lockbits:develop` (pre-production)
