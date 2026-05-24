# 🔒 Sécurité — LockBits

## Politique de sécurité

LockBits prend la sécurité de son infrastructure et de ses données au sérieux.
Ce document décrit les bonnes pratiques, la procédure de signalement de vulnérabilités,
et les engagements en matière de sécurité.

## Sécurité de l'infrastructure

### Authentification

L'API EDR expose des endpoints sensibles (collecte de données, exécution de commandes).
**L'authentification via `AUTH_TOKEN` est obligatoire en production.**

```env
AUTH_TOKEN=<token-sécurisé-généré-aléatoirement>
```

### Base de données

- **MySQL** est la base de production recommandée. SQLite est acceptable uniquement en développement.
- Les mots de passe par défaut doivent être changés immédiatement après le premier déploiement.
- Les identifiants sont passés via variables d'environnement, jamais hardcodés.

### Réseau

- L'infrastructure Docker utilise un réseau **2 tiers** : `frontend` (serveurs exposés) et `backend` (base de données uniquement).
- La base de données n'est **pas exposée** sur l'hôte en production.
- Un **reverse proxy** (nginx/Caddy/Traefik) avec **TLS/HTTPS** est requis pour toute exposition publique.

### Bonnes pratiques

- [ ] Changer tous les mots de passe par défaut avant déploiement
- [ ] Configurer un `AUTH_TOKEN` fort (≥ 32 caractères aléatoires)
- [ ] Activer HTTPS via un reverse proxy
- [ ] Restreindre les origines CORS aux domaines autorisés
- [ ] Ne pas exposer les ports MySQL/phpMyAdmin en production
- [ ] Activer le rate limiting sur les endpoints sensibles
- [ ] Scanner régulièrement les images Docker avec Trivy

## Signalement de vulnérabilités

Si vous découvrez une vulnérabilité de sécurité dans LockBits,
**ne créez pas d'issue publique**. Contactez l'équipe directement :

- **Email** : [cleeryy@example.com](mailto:cleeryy@example.com)
- Ou contactez un membre de l'organisation LockBits-ESGI sur GitHub.

Nous nous engageons à :

1. Accuser réception sous **48 heures**
2. Analyser et reproduire la vulnérabilité sous **5 jours ouvrés**
3. Communiquer un correctif ou un plan d'action sous **15 jours ouvrés**
4. Créditer le rapporteur (si souhaité) dans l'annonce de correctif

## Changelog sécurité

| Date | Changement |
|------|-----------|
| 2026-05-24 | Document initial |
