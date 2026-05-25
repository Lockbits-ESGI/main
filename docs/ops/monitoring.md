# Monitoring

La stack LockBits s'appuie sur plusieurs outils pour assurer la supervision des services, la collecte des logs et la mise a jour automatique des conteneurs.

## Metriques avec Prometheus et Grafana

Le serveur EDR (FastAPI) expose des metriques au format Prometheus via le endpoint `/metrics`. Ces metriques incluent :

- Le nombre de requetes par endpoint.
- Le temps de reponse des requetes.
- Le nombre d'analyses de fichiers effectuees.
- L'etat de la connexion a la base de donnees.
- Les erreurs serveur.

Pour configurer la collecte :

1. Deployez Prometheus pour scraper le endpoint `/metrics` de l'EDR.
2. Configurez Grafana pour visualiser les donnees collectees par Prometheus.
3. Importez ou creez des tableaux de bord pour les indicateurs cles.

Exemple de configuration Prometheus (`prometheus.yml`) :

```yaml
scrape_configs:
  - job_name: 'lockbits-edr'
    scrape_interval: 15s
    static_configs:
      - targets: ['lockbits_edr:8000']
```

Grafana n'est pas inclus dans la stack Docker par defaut. Il doit etre deploye separement, soit sur le meme hote, soit sur une infrastructure dediee.

## Logs avec Loki et Alloy

Les logs des conteneurs Docker sont collectes et centralises via Loki, avec l'agent Alloy pour l'acheminement.

Architecture de collecte :

```
Conteneurs Docker
       │
       ▼
    Alloy (agent de collecte)
       │
       ▼
    Loki (stockage et indexation)
       │
       ▼
    Grafana (visualisation)
```

Loki permet de centraliser les logs de tous les conteneurs de la stack (`lockbits_edr`, `lockbits_web`, `lockbits_db`) et d'y acceder via Grafana avec des requetes de type LogQL.

Pour deployer Loki et Alloy, vous pouvez utiliser les images Docker officielles :

```bash
docker run -d --name loki -p 3100:3100 grafana/loki:latest
docker run -d --name alloy grafana/alloy:latest
```

La configuration d'Alloy doit definir les targets de collecte (les conteneurs LockBits) et la destination d'expedition (le endpoint Loki).

## Mise a jour automatique avec Watchtower

Watchtower est integre directement dans les fichiers `docker-compose.prod.yml` et `docker-compose.preprod.yml`. Il utilise le fork maintenu `nickfedor/watchtower` (l'original `containrrr/watchtower` est archive et n'est plus compatible avec les API Docker recentes).

### Configuration

```yaml
watchtower:
  image: nickfedor/watchtower
  container_name: lockbits_watchtower
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  command: --interval 300 --cleanup
  restart: unless-stopped
```

Options :

- `--interval 300` : verifie les nouvelles images toutes les 5 minutes.
- `--cleanup` : supprime les anciennes images apres mise a jour pour liberer de l'espace disque.

Watchtower surveille tous les conteneurs en cours d'execution sur le daemon Docker. Quand une nouvelle image est detectee sur le registry, il arrete proprement le conteneur concerne et le redemarre avec la nouvelle image.

### Surveillance des mises a jour

Les logs de Watchtower sont visibles via :

```bash
docker logs lockbits_watchtower
docker compose -f docker-compose.prod.yml logs watchtower
```

### Alternative cron

Pour les environnements sans Watchtower (ou comme couche supplementaire), le script `install.sh` propose un mode `--cron` qui ajoute une entree crontab pour verifier et appliquer les mises a jour toutes les 5 minutes :

```bash
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash -s -- --cron
```

Les logs de mise a jour sont stockes dans `update.log` dans le repertoire d'installation.

## Healthchecks

Chaque service dispose d'un healthcheck Docker qui verifie periodiquement son bon fonctionnement :

- **EDR** : requete HTTP GET vers `/health` toutes les 30 secondes.
- **Site web** : requete HTTP GET vers `/` toutes les 30 secondes.
- **MySQL** : `mysqladmin ping` toutes les 30 secondes.

Les healthchecks sont configures avec un `start_period` pour laisser le temps au service de demarrer avant les premieres verifications.
