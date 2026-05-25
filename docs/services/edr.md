# Service EDR (FastAPI)

Le service EDR (Endpoint Detection and Response) est le composant backend de LockBits. Il est developpe en Python avec le framework FastAPI et expose une API REST pour la gestion des agents de detection sur les terminaux.

## Architecture interne

Le code source se trouve dans le sous-module `edr/` du depot principal. La structure du projet EDR comprend :

- `server/` : le serveur API FastAPI avec les routes et la logique metier.
- `client/` : l'agent EDR installe sur les terminaux clients.
- `packaging/` : les scripts de build et de packaging.
- `tests/` : les tests unitaires et d'integration avec pytest.

## Endpoints API

### `/health` — Sante du service

Requete :

```bash
curl http://localhost:8001/health
```

Reponse :

```json
{"status": "ok", "db_ok": true}
```

Cet endpoint permet de verifier que le serveur est operationnel et que la connexion a la base de donnees est fonctionnelle. Il est utilise par Docker pour les healthchecks et par Watchtower pour verifier que le service est pret.

### `/scan` — Analyse de fichiers

Endpoint consacre a la soumission de fichiers pour analyse. L'agent EDR envoie les fichiers suspects collectes sur les terminaux.

L'analyse peut etre enrichie par l'integration VirusTotal si la fonctionnalite est activee (`VT_ENABLED=true`) et qu'une cle API valide est configuree (`VT_API_KEY`). VirusTotal permet de comparer les fichiers contre une base de donnees mondiale de signatures de malwares.

### `/monitor` — Monitoring des terminaux

Endpoint de collecte des donnees de monitoring en provenance des agents. Les agents transmettent periodiquement des informations sur l'etat des terminaux : processus actifs, connexions reseau, modifications de fichiers, et evenements systeme.

## Authentification

Tous les endpoints, a l'exception de `/health`, sont proteges par une authentification via token. Le token est configure dans la variable d'environnement `AUTH_TOKEN` :

```env
AUTH_TOKEN=<token-securise-de-32-caracteres-minimum>
```

Les requetes doivent inclure le token dans l'en-tete HTTP `Authorization` :

```bash
curl -H "Authorization: Bearer <token>" http://localhost:8001/scan
```

En environnement de developpement, si `AUTH_TOKEN` est laisse vide, l'authentification est desactivee. En production, un token doit obligatoirement etre defini.

## Base de donnees

Le serveur EDR peut utiliser deux types de bases de donnees :

- **SQLite** (developpement) : stockage dans un fichier local (`/app/data/miniedr.db`). Simple, sans configuration, adapte au developpement local et aux tests.
- **PostgreSQL** (production) : configure via la variable `DATABASE_URL` au format `postgresql://user:password@host:port/dbname`. Necessite un serveur PostgreSQL externe.

En production, l'utilisation de PostgreSQL est fortement recommandee pour la fiabilite, la concurrence et la perennite des donnees.

## Configuration

Variables d'environnement du service EDR :

| Variable       | Description                                      | Valeur par defaut          |
|----------------|--------------------------------------------------|----------------------------|
| `SERVER_HOST`  | Adresse d'ecoute du serveur                      | `0.0.0.0`                  |
| `SERVER_PORT`  | Port d'ecoute du serveur                         | `8000`                     |
| `DATABASE_URL` | URL de connexion a la base de donnees            | `sqlite:///./miniedr.db`   |
| `AUTH_TOKEN`   | Token d'authentification pour l'API              | — (obligatoire en prod)    |
| `VT_ENABLED`   | Activer l'integration VirusTotal                 | `false`                    |
| `VT_API_KEY`   | Cle API VirusTotal                               | —                          |
| `CORS_ORIGINS` | Origines CORS autorisees (separes par virgules)  | `*`                        |
| `LOG_LEVEL`    | Niveau de log (DEBUG, INFO, WARNING, ERROR)      | `INFO`                     |

## Integration VirusTotal

Quand l'integration VirusTotal est activee, le serveur EDR peut, pour chaque fichier soumis :

1. Calculer l'empreinte (hash) du fichier.
2. Interroger l'API VirusTotal pour verifier si le hash est deja connu.
3. Si le fichier est inconnu, le telecharger pour analyse.
4. Retourner le rapport d'analyse avec le score de detection.

Cette integration necessite une cle API VirusTotal valide. Le niveau d'acces de la cle determine le nombre de requetes autorisees par jour.
