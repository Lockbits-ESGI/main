#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# LockBits — Quick Install / Update
# ─────────────────────────────────────────────────────────────────────────────
# Usage :
#   curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --update        # mise à jour rapide
#
# Avec un token GHCR :
#   curl -fsSL ... | GITHUB_TOKEN=<token> bash
#   curl -fsSL ... | GITHUB_TOKEN=<token> bash -s -- --update
#
# Variables d'environnement :
#   GITHUB_TOKEN   Token GHCR avec accès aux images privées
#   LOCKBITS_DIR   Répertoire d'installation (défaut : répertoire courant)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="Lockbits-ESGI/main"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
header(){ echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ── Mode detection ─────────────────────────────────────────────────────────
MODE="install"
CRON_INTERVAL=5
ENV_TARGET="prod"
for arg in "$@"; do
    case "$arg" in
        --update|-u) MODE="update" ;;
    --cron)              MODE="cron" ;;
    --no-cron)           MODE="no-cron" ;;
    --interval=*)        CRON_INTERVAL="${arg#*=}" ;;
    --update-sources)    MODE="update-sources" ;;
    --env=*)             ENV_TARGET="${arg#*=}" ;;
    --help|-h)           MODE="help" ;;
    esac
done

# ── Validate env target ────────────────────────────────────────────────────
case "$ENV_TARGET" in
    prod|preprod) ;;
    *) error "Valeur invalide pour --env : '$ENV_TARGET'. Utilisez 'prod' ou 'preprod'." ;;
esac

# ── Help ────────────────────────────────────────────────────────────────────
if [ "$MODE" = "help" ]; then
    echo "LockBits — Quick Install, Update & Auto-Update"
    echo ""
    echo "Usage:"
    echo "  curl -fsSL $BASE_URL/install.sh | bash                          # Install (prod)"
    echo "  curl -fsSL $BASE_URL/install.sh | bash -s -- --update           # Update"
    echo "  curl -fsSL $BASE_URL/install.sh | bash -s -- --cron             # Auto-update (cron)"
    echo "  curl -fsSL $BASE_URL/install.sh | bash -s -- --no-cron          # Stop auto-update"
    echo "  curl -fsSL $BASE_URL/install.sh | bash -s -- --cron --interval=10  # Custom interval"
    echo ""
    echo "Modes :"
    echo "  (default)        Installation complète (production)"
    echo "  --env=preprod    Installation préproduction (:develop images)"
    echo "  --update,-u      Mise à jour rapide"
    echo "  --cron           Active la mise à jour automatique (cron, toutes les 5 min)"
    echo "  --no-cron        Désactive la mise à jour automatique"
    echo "  --interval=N     Intervalle en minutes (défaut: 5, use with --cron)"
    echo "  --update-sources Met à jour les submodules git et push (déclenche CI)"
    echo ""
    echo "Variables d'environnement :"
    echo "  GITHUB_TOKEN=<token>   Token GHCR pour les images privées"
    echo "  LOCKBITS_DIR=<path>    Répertoire d'installation"
    exit 0
fi

# ── Cron setup ──────────────────────────────────────────────────────────────
if [ "$MODE" = "cron" ] || [ "$MODE" = "no-cron" ]; then
    header "LockBits — Mise à jour automatique"

    INSTALL_DIR="${LOCKBITS_DIR:-.}"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    INSTALL_DIR="$(pwd)"

    if ! command -v crontab &>/dev/null; then
        error "crontab n'est pas disponible sur ce système"
    fi

    CRON_MARKER="# LOCKBITS_AUTO_UPDATE"
    LOG_FILE="$INSTALL_DIR/update.log"

    if [ "$MODE" = "no-cron" ]; then
        if crontab -l 2>/dev/null | grep -q "$CRON_MARKER"; then
            crontab -l 2>/dev/null | grep -v "$CRON_MARKER" | grep -v "^# LOCKBITS_AUTO_UPDATE$" | crontab -
            info "Mise à jour automatique (cron) désactivée"
        else
            info "Aucune mise à jour automatique (cron) active"
        fi
        exit 0
    fi

    # Vérifier si déjà configuré
    if crontab -l 2>/dev/null | grep -q "$CRON_MARKER"; then
        warn "Mise à jour automatique (cron) déjà active"
        info "Pour la désactiver : bash install.sh --no-cron"
        exit 0
    fi

    # Créer la ligne cron
    CRON_LINE="*/$CRON_INTERVAL * * * * cd $INSTALL_DIR && curl -fsSL $BASE_URL/install.sh | bash -s -- --update >> $LOG_FILE 2>&1"

    (crontab -l 2>/dev/null || true; echo "$CRON_LINE"; echo "$CRON_MARKER") | crontab -

    info "Mise à jour automatique (cron) activée toutes les $CRON_INTERVAL minutes"
    info "Logs : $LOG_FILE"
    exit 0
fi

# ── Update sources (submodules) ───────────────────────────────────────────
if [ "$MODE" = "update-sources" ]; then
    header "LockBits — Mise à jour des sources"

    if ! git rev-parse --git-dir &>/dev/null; then
        error "Pas dans un dépôt git. Exécutez cette commande depuis le clone du repo principal (Lockbits-ESGI/main)"
    fi

    # Initialiser les submodules si pas déjà fait
    if [ ! -f .gitmodules ]; then
        error "Aucun .gitmodules trouvé — êtes-vous dans le bon repo ?"
    fi

    info "Mise à jour des submodules..."
    git submodule update --remote --merge

    if git diff --quiet --exit-code; then
        info "Tous les submodules sont déjà à jour"
    else
        info "Modifications détectées, création du commit..."
        git add -u
        git commit -m "update submodules to latest"
        info "Commit créé"

        read -rp "Pousser sur origin/main ? [Y/n] " REPLY
        if [[ "$REPLY" =~ ^[Yy]?$ ]]; then
            git push origin main
            info "Pushé — la CI va rebuild les images"
        else
            warn "Push annulé. Faites-le manuellement : git push origin main"
        fi
    fi

    echo ""
    info "Une fois les images rebuildées par la CI, mettez à jour le serveur avec :"
    info "  curl -fsSL $BASE_URL/install.sh | bash -s -- --update"
    exit 0
fi

if [ "$MODE" = "update" ]; then
    header "LockBits — Mise à jour"
else
    header "LockBits — Quick Install"
fi

# ── 1. Vérifier Docker (uniquement en mode install) ─────────────────────────
if [ "$MODE" = "install" ]; then
    if ! command -v docker &>/dev/null; then
        error "Docker n'est pas installé. Voir https://docs.docker.com/get-docker/"
    fi
    info "Docker trouvé : $(docker --version | cut -d' ' -f3 | tr -d ',')"
fi

COMPOSE_CMD=""
if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
elif docker-compose --version &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    error "Docker Compose n'est pas installé"
fi
info "Compose : $($COMPOSE_CMD version | head -1)"

# ── 2. Répertoire ──────────────────────────────────────────────────────────
INSTALL_DIR="${LOCKBITS_DIR:-.}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
info "Répertoire : $(pwd)"

# ── 3. Déterminer le fichier compose ──────────────────────────────────────
if [ "$ENV_TARGET" = "preprod" ]; then
    COMPOSE_FILE="docker-compose.preprod.yml"
    COMPOSE_DISPLAY="Preprod"
else
    COMPOSE_FILE="docker-compose.prod.yml"
    COMPOSE_DISPLAY="Production"
fi

# ── 4. Télécharger les fichiers de configuration ────────────────────────────
header "Fichiers de configuration ($COMPOSE_DISPLAY)"

for file in "$COMPOSE_FILE" .env.example; do
    info "Téléchargement de $file..."
    curl -fsSL -o "$file" "$BASE_URL/$file"
done

# ── 4. Gérer .env ──────────────────────────────────────────────────────────
if [ "$MODE" = "update" ] && [ -f .env ]; then
    # En mode update : détecter les nouvelles variables
    NEW_VARS=$(grep -E '^[A-Z_]+=' .env.example | cut -d= -f1 | while IFS= read -r var; do
        grep -q "^$var=" .env 2>/dev/null || echo "  $var"
    done)
    if [ -n "$NEW_VARS" ]; then
        warn "Nouvelles variables dans .env.example (à ajouter dans .env) :"
        echo "$NEW_VARS"
        echo ""
        warn "Exécutez : cat .env.example >> .env puis éditez .env"
    else
        info "Aucune nouvelle variable détectée"
    fi
elif [ ! -f .env ]; then
    cp .env.example .env
    info ".env créé depuis .env.example"
    if [ "$MODE" = "install" ]; then
        warn "PENSEZ À ÉDITER .env avec vos vraies valeurs (tokens API, etc.)"
    fi
else
    info ".env conservé"
fi

# ── 5. Connexion GHCR ──────────────────────────────────────────────────────
if [ "$MODE" = "install" ]; then
    header "Connexion au registry"

    if docker system info 2>/dev/null | grep -q "ghcr.io"; then
        info "Déjà connecté à ghcr.io"
    elif [ -n "${GITHUB_TOKEN:-}" ]; then
        GHCR_USER="${GITHUB_USER:-$(whoami)}"
        if echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin 2>/dev/null; then
            info "Connecté à ghcr.io en tant que $GHCR_USER"
        else
            warn "Échec de connexion à ghcr.io — vérifiez votre GITHUB_TOKEN"
        fi
    else
        warn "GITHUB_TOKEN non défini"
        warn "Les images sont privées → connectez-vous d'abord :"
        warn "  echo \$GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin"
    fi
fi

# ── 6. Déploiement ─────────────────────────────────────────────────────────
header "Déploiement"

if [ "$MODE" = "update" ]; then
    info "Redémarrage de la stack avec les dernières images..."
else
    info "Lancement de la stack LockBits..."
fi

$COMPOSE_CMD -f "$COMPOSE_FILE" up -d

# ── 7. Vérification ────────────────────────────────────────────────────────
header "Vérification"

echo -n "Attente des services "
for i in $(seq 1 12); do
    echo -n "."
    sleep 2
done
echo ""

EDR=false
SITE=false

if curl -sf http://localhost:8001/health >/dev/null 2>&1; then
    info "EDR Server  → http://localhost:8001  (✓)"
    EDR=true
else
    warn "EDR Server  → pas encore prêt (vérifiez avec docker compose logs)"
fi

if curl -sf http://localhost:8080/ >/dev/null 2>&1; then
    info "Site Web    → http://localhost:8080  (✓)"
    SITE=true
else
    warn "Site Web    → pas encore prêt (vérifiez avec docker compose logs)"
fi

echo ""
if [ "$MODE" = "update" ]; then
    if $EDR || $SITE; then
        info "Mise à jour terminée !"
    else
        warn "Les services redémarrent... Vérifiez avec :"
        warn "  $COMPOSE_CMD -f $COMPOSE_FILE logs -f"
    fi
elif $EDR || $SITE; then
    info "Installation terminée avec succès !"
else
    warn "Les services sont encore en cours de démarrage."
    warn "Surveillez avec : $COMPOSE_CMD -f $COMPOSE_FILE logs -f"
fi
echo ""
info "Commandes :"
info "  Logs          : $COMPOSE_CMD -f $COMPOSE_FILE logs -f"
info  "  Arrêter       : $COMPOSE_CMD -f $COMPOSE_FILE down"
info  "  Mettre à jour : curl -fsSL $BASE_URL/install.sh | bash -s -- --update"
