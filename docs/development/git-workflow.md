# Workflow Git

LockBits suit un modele de branches derive de Git Flow, simplifie pour un projet a deux composants avec deploiement continu.

## Strategie de branches

Le depot principal utilise trois niveaux de branches :

```
feature/* ──PR──→ develop ──PR──→ main (protegee)
fix/*     ──PR──→ develop ╱
```

### Branche `main`

La branche `main` contient le code de production. Elle est protegee : aucun push direct n'est autorise. Toute modification doit passer par une pull request depuis `develop` avec une review approuvee et le succes de tous les checks CI.

Les evenements sur `main` declenchent la construction et la publication des images Docker avec le tag `:latest`.

### Branche `develop`

La branche `develop` est la branche d'integration active. C'est la base de toutes les branches de fonctionnalites. Les pull requests depuis les branches `feature/*` ou `fix/*` sont mergees ici.

Les evenements sur `develop` declenchent la construction et la publication des images Docker avec le tag `:develop`, qui alimentent l'environnement de pre-production.

### Branches `feature/*` et `fix/*`

Les branches de travail sont toujours creees a partir de `develop` :

```bash
git checkout develop
git pull
git checkout -b feat/ma-fonctionnalite
```

Apres avoir travaille, push et creez une pull request vers `develop`.

## Conventions de nommage

Les branches suivent un prefixe qui indique le type de travail :

| Type     | Prefixe | Exemple                        |
|----------|---------|--------------------------------|
| Feature  | `feat/` | `feat/authentification-2fa`    |
| Fix      | `fix/`  | `fix/cors-prod`                |
| Refactor | `refactor/` | `refactor/docker-multi-stage` |
| Docs     | `docs/` | `docs/securite`                |
| CI       | `ci/`   | `ci/security-scan`             |

Les noms de branches sont en kebab-case et en francais ou en anglais.

## Processus de pull request

### Creation d'une pull request

1. Assurez-vous que les tests passent localement.
2. Poussez votre branche sur GitHub.
3. Creez une pull request depuis votre branche `feature/*` vers `develop`.
4. Decrivez clairement les changements, le contexte et les tests effectues.
5. Liez l'issue correspondante si elle existe (exemple : `Closes #42`).

### Review et merge

- Les pull requests vers `develop` necessitent le succes des checks CI.
- Les pull requests vers `main` necessitent en plus une review approuvee et que la branche soit a jour avec `main`.
- Les merges vers `main` doivent toujours provenir de `develop`, jamais directement d'une branche `feature/*`.

### Template de pull request

```markdown
## Description
Breve description des changements.

## Contexte
Pourquoi ce changement est necessaire.

## Changements
- [ ] Correction de bug
- [ ] Nouvelle fonctionnalite
- [ ] Changement cassant (breaking)
- [ ] Documentation

## Tests
- [ ] Tests unitaires passent
- [ ] Tests integration passent
- [ ] Teste manuellement

## Issues liees
Fixes #...
```

## Messages de commit

Les messages de commit suivent la convention des commits conventionnels. Ils peuvent etre en francais ou en anglais, a l'imperatif.

Exemples :

- `feat: add rate limiting on /api/v1/scan`
- `fix: restrict CORS origins in production`
- `docs: mettre a jour le README avec les instructions de deploiement`
- `ci: ajouter le scan Trivy dans le pipeline`

Un commit doit representer une modification logique unique. Evitez les commits trop volumineux qui melangent plusieurs changements sans rapport.

## Regles importantes

- Ne jamais push directement sur `main` (la branche est protegee).
- Toujours partir de `develop` pour les nouvelles branches.
- Mettre a jour les sous-modules avec `install.sh --update-sources` apres un changement dans `edr/` ou `site_lockbits/`.
- Les branches feature doivent etre supprimees apres le merge de la pull request.
