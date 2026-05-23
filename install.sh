#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# LockBits — Quick Install
# ─────────────────────────────────────────────────────────────────────────────
# Usage :
#   curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash
#
# Ou avec un token GHCR :
#   curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | GITHUB_TOKEN=<token> bash
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

# ── Help ────────────────────────────────────────────────────────────────────
if [[ "${1:-}" = "--help" || "${1:-}" = "-h" ]]; then
    echo "LockBits — Quick Install"
    echo ""
    echo "Usage:"
    echo "  curl -fsSL $BASE_URL/install.sh | bash"
    echo ""
    echo "Variables d'environnement :"
    echo "  GITHUB_TOKEN=<token>   Token GHCR pour les images privées"
    echo "  LOCKBITS_DIR=<path>    Répertoire d'installation"
    echo ""
    echo "Étapes :"
    echo "  1. Vérifie que Docker + Docker Compose sont installés"
    echo "  2. Télécharge docker-compose.prod.yml et .env.example depuis GitHub"
    echo "  3. Crée .env à partir de .env.example si absent"
    echo "  4. Se connecte à ghcr.io si GITHUB_TOKEN est défini"
    echo "  5. Lance docker compose up -d"
    echo "  6. Vérifie que les services répondent"
    exit 0
fi

header "LockBits — Quick Install"

# ── 1. Vérifier Docker ─────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    error "Docker n'est pas installé. Voir https://docs.docker.com/get-docker/"
fi
info "Docker trouvé : $(docker --version | cut -d' ' -f3 | tr -d ',')"

COMPOSE_CMD=""
if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
elif docker-compose --version &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    error "Docker Compose n'est pas installé"
fi
info "Compose trouvé : $($COMPOSE_CMD version | head -1)"

# ── 2. Répertoire d'installation ───────────────────────────────────────────
INSTALL_DIR="${LOCKBITS_DIR:-.}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
info "Installation dans : $(pwd)"

# ── 3. Télécharger les fichiers de configuration ────────────────────────────
header "Téléchargement des fichiers"

for file in docker-compose.prod.yml .env.example; do
    info "Téléchargement de $file..."
    curl -fsSL -o "$file" "$BASE_URL/$file"
done

# ── 4. Créer .env ──────────────────────────────────────────────────────────
if [ ! -f .env ]; then
    cp .env.example .env
    info ".env créé depuis .env.example"
    warn "PENSEZ À ÉDITER .env avec vos vraies valeurs (tokens API, etc.)"
else
    info ".env existant conservé"
fi

# ── 5. Connexion GHCR ──────────────────────────────────────────────────────
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

# ── 6. Déploiement ─────────────────────────────────────────────────────────
header "Déploiement"

info "Lancement de la stack LockBits..."
$COMPOSE_CMD -f docker-compose.prod.yml up -d

# ── 7. Vérification ────────────────────────────────────────────────────────
header "Vérification des services"

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
if $EDR || $SITE; then
    info "Installation terminée avec succès !"
else
    warn "Les services sont encore en cours de démarrage."
    warn "Surveillez avec : $COMPOSE_CMD -f docker-compose.prod.yml logs -f"
fi
echo ""
info "Commandes utiles :"
info "  Voir les logs  : $COMPOSE_CMD -f docker-compose.prod.yml logs -f"
info "  Arrêter        : $COMPOSE_CMD -f docker-compose.prod.yml down"
info "  Mettre à jour  : $COMPOSE_CMD -f docker-compose.prod.yml up -d"
