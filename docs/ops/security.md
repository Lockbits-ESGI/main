# Securite

Cette page regroupe les bonnes pratiques et les mecanismes de securite mis en place dans le projet LockBits.

## Authentification obligatoire

L'API EDR expose des endpoints sensibles (collecte de donnees, analyse de fichiers, execution de commandes). L'authentification via le token `AUTH_TOKEN` est obligatoire en production.

Configuration dans `.env` :

```env
EDR_AUTH_TOKEN=<token-securise-de-32-caracteres-minimum>
```

Le token est transmis dans l'en-tete `Authorization` de chaque requete :

```bash
curl -H "Authorization: Bearer <token>" http://localhost:8001/scan
```

En developpement, si `AUTH_TOKEN` est vide, l'authentification est desactivee pour faciliter les tests. En production, un token fort doit absolument etre configure.

## Gestion des secrets

Les secrets (mots de passe, tokens API, cles) sont geres exclusivement via des variables d'environnement. Aucun secret n'est hardcode dans le code source ou les fichiers de configuration.

Le fichier `.env` contient tous les secrets de l'application. Il est exclu du versionnement via `.gitignore`. Les valeurs par defaut dans `.env.example` et dans les fichiers `docker-compose*.yml` sont des valeurs de demonstration qui doivent etre changees avant tout deploiement en production.

Liste des secrets a personnaliser :

- `EDR_AUTH_TOKEN` : token d'authentification de l'API EDR.
- `DB_ROOT_PASSWORD` : mot de passe root MySQL.
- `DB_PASS` : mot de passe de l'utilisateur applicatif MySQL.
- `VT_API_KEY` : cle API VirusTotal.
- `GLPI_APP_TOKEN`, `GLPI_USER_TOKEN`, `GLPI_OAUTH_CLIENT_SECRET`, `GLPI_API_PASSWORD` : secrets d'integration GLPI.

## Securite reseau

L'infrastructure Docker utilise un reseau a deux niveaux :

- **Reseau frontend** : accessible depuis l'exterieur. Seuls l'EDR et le site web y sont connectes.
- **Reseau backend** : isole, aucun port expose sur l'hote. Seuls le site web et la base de donnees MySQL y sont connectes.

La base de donnees MySQL n'est jamais exposee directement sur l'hote en production. En developpement, le port 3307 peut etre expose pour les outils de gestion, mais cette exposition doit etre desactivee en production.

Un reverse proxy (nginx, Caddy, Traefik) avec chiffrement TLS/HTTPS est requis pour toute exposition publique des services. La configuration du reverse proxy n'est pas incluse dans la stack Docker et doit etre mise en place separement.

## CORS (Cross-Origin Resource Sharing)

Le serveur EDR configure les en-tetes CORS via la variable `CORS_ORIGINS`. En developpement, la valeur `*` autorise toutes les origines. En production, cette valeur doit etre restreinte aux domaines autorises :

```env
CORS_ORIGINS=https://mon.domaine.com,https://api.mon.domaine.com
```

## Rate limiting

Le rate limiting est recommande sur les endpoints sensibles de l'API EDR, en particulier `/scan` et les endpoints d'authentification. FastAPI permet d'integrer des middlewares de rate limiting comme `slowapi` ou `django-ratelimit`.

Bien que le rate limiting ne soit pas configure par defaut dans la stack actuelle, il est fortement recommande de l'activer avant tout deploiement en production pour prevenir les abus et les attaques par force brute.

## Scan de securite avec Trivy

Le pipeline CI inclut une etape de scan de securite avec Trivy apres la construction et la publication des images Docker.

Le scan analyse :

- Les vulnerabilites des paquets systeme (OS).
- Les vulnerabilites des bibliotheques applicatives (Python, PHP, etc.).
- Les niveaux de severite CRITICAL et HIGH uniquement.

Les resultats sont affiches dans les logs de la pipeline mais n'echouent pas le build (`exit-code: 0`). Ils constituent un rapport a examiner pour les mainteneurs du projet.

Pour scanner une image localement :

```bash
docker pull ghcr.io/lockbits-esgi/edr:latest
trivy image ghcr.io/lockbits-esgi/edr:latest
```

## Pre-commit hooks

Le projet utilise des pre-commit hooks pour appliquer automatiquement les conventions de code et detecter les problemes avant le commit. Les hooks configures incluent :

- Formatage du code Python avec Black.
- Tri des imports avec isort.
- Linting avec Ruff.
- Verification des fichiers de configuration YAML.

Pour installer les hooks localement :

```bash
pip install pre-commit
pre-commit install
```

## Bonnes pratiques

1. Changer tous les mots de passe par defaut avant le premier deploiement.
2. Configurer un `AUTH_TOKEN` fort (minimum 32 caracteres aleatoires).
3. Activer HTTPS via un reverse proxy.
4. Restreindre les origines CORS aux domaines autorises.
5. Ne pas exposer les ports MySQL en production.
6. Activer le rate limiting sur les endpoints sensibles.
7. Scanner regulierement les images Docker avec Trivy.
8. Surveiller les logs pour detecter les tentatives d'acces non autorisees.
9. Maintenir les dependances a jour via Dependabot (configure en hebdomadaire).
