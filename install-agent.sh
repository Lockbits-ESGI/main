#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# LockBits EDR Agent — Installer
#
# Installs the EDR agent on client machines in either:
#   --mode binary   (default)  PyInstaller standalone binary
#   --mode docker              Docker container (pulls GHCR image)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install-agent.sh | \
#     SERVER_URL=https://edr.lockbits.io AUTH_TOKEN=xxx bash
#
#   curl -fsSL https://.../install-agent.sh | \
#     SERVER_URL=... AUTH_TOKEN=... bash -s -- --mode docker
# ─────────────────────────────────────────────────────────────

# ── Config ───────────────────────────────────────────────────
readonly REPO_OWNER="Lockbits-ESGI"
readonly REPO_NAME="edr"
readonly GHCR_IMAGE="ghcr.io/lockbits-esgi/edr-agent"
readonly BINARY_NAME="lockbits-agent"
readonly INSTALL_DIR="/usr/local/bin"
readonly CONFIG_DIR="/etc/lockbits-agent"
readonly DATA_DIR="/opt/lockbits-agent"
readonly SYSTEMD_SERVICE="lockbits-agent.service"
readonly DOCKER_CONTAINER_NAME="lockbits-agent"

# GitHub Releases base URL (binary downloads)
RELEASE_VERSION="latest"
GH_BASE="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases"

# ── Help ─────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
LockBits EDR Agent — Installer

Installs the EDR agent on your machine. Requires SERVER_URL and AUTH_TOKEN.

Environment variables:
  SERVER_URL   URL of the LockBits EDR server (required)
  AUTH_TOKEN   Authentication token for the EDR server (required)
  AGENT_MODE   Agent operation mode: monitor (default) or scan

Options:
  --mode MODE           Installation mode: binary (default) or docker
  --auto-install-docker If Docker is missing, install it automatically
  --version VERSION     Pin a specific version (default: latest)
  --update              Re-download / re-pull and restart the agent
  --uninstall           Stop and remove the agent completely
  --status              Check if the agent is running
  --help                Show this help

Examples:
  SERVER_URL=https://edr.lockbits.io AUTH_TOKEN=xxx bash install-agent.sh
  SERVER_URL=https://edr.lockbits.io AUTH_TOKEN=xxx bash install-agent.sh --mode docker --auto-install-docker
  bash install-agent.sh --update
  bash install-agent.sh --uninstall
EOF
    exit 0
}

# ── Helper functions ─────────────────────────────────────────
log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }
fatal()     { log_error "$*"; exit 1; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        fatal "This script must be run as root (sudo)."
    fi
}

detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) fatal "Unsupported architecture: $arch (supported: amd64, arm64)" ;;
    esac
}

detect_os() {
    local os
    os="$(uname -s)"
    case "$(echo "$os" | tr '[:upper:]' '[:lower:]')" in
        linux) echo "linux" ;;
        darwin) fatal "macOS agent install is not yet supported. Coming soon." ;;
        *) fatal "Unsupported OS: $os" ;;
    esac
}

ensure_server_url() {
    if [ -z "${SERVER_URL:-}" ]; then
        if [ -f "$CONFIG_DIR/config.env" ]; then
            SERVER_URL="$(grep '^SERVER_URL=' "$CONFIG_DIR/config.env" | head -1 | cut -d= -f2-)" || true
        fi
    fi
    if [ -z "${SERVER_URL:-}" ]; then
        fatal "SERVER_URL is required. Set it as an environment variable."
    fi
    # Strip trailing slash
    SERVER_URL="${SERVER_URL%/}"
}

ensure_auth_token() {
    if [ -z "${AUTH_TOKEN:-}" ]; then
        if [ -f "$CONFIG_DIR/config.env" ]; then
            AUTH_TOKEN="$(grep '^AUTH_TOKEN=' "$CONFIG_DIR/config.env" | head -1 | cut -d= -f2-)" || true
        fi
    fi
    if [ -z "${AUTH_TOKEN:-}" ]; then
        fatal "AUTH_TOKEN is required. Set it as an environment variable."
    fi
}

check_docker() {
    if command -v docker &>/dev/null; then
        return 0
    fi
    return 1
}

install_docker() {
    log_info "Docker not found. Installing Docker via get.docker.com..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    log_info "Docker installed successfully."
}

systemd_unit_binary() {
    local server_url="$1"
    local auth_token="$2"
    local agent_mode="${AGENT_MODE:-monitor}"

    cat > "/etc/systemd/system/$SYSTEMD_SERVICE" <<UNIT
[Unit]
Description=LockBits EDR Agent
Documentation=https://github.com/Lockbits-ESGI/edr
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/${BINARY_NAME} --mode ${agent_mode}
Restart=always
RestartSec=10
EnvironmentFile=${CONFIG_DIR}/config.env
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT
}

systemd_unit_docker() {
    local server_url="$1"
    local auth_token="$2"
    local agent_mode="${AGENT_MODE:-monitor}"

    cat > "/etc/systemd/system/$SYSTEMD_SERVICE" <<UNIT
[Unit]
Description=LockBits EDR Agent (Docker)
Documentation=https://github.com/Lockbits-ESGI/edr
After=docker.service network-online.target
Wants=docker.service network-online.target
Requires=docker.service

[Service]
Type=simple
ExecStartPre=-/usr/bin/docker rm -f ${DOCKER_CONTAINER_NAME} 2>/dev/null
ExecStart=/usr/bin/docker run \\
    --name ${DOCKER_CONTAINER_NAME} \\
    --rm \\
    --pid=host \\
    --network=host \\
    --privileged \\
    -v /:/host:ro \\
    -v /etc:/host/etc:ro \\
    -v /tmp:/host/tmp:ro \\
    -v ${DATA_DIR}/data:/app/data \\
    -v ${DATA_DIR}/queue:/app/queue \\
    -v ${DATA_DIR}/logs:/app/logs \\
    -e MINIEDR_SERVER_URL=${server_url} \\
    -e MINIEDR_AUTH_TOKEN=${auth_token} \\
    -e MINIEDR_MODE=${agent_mode} \\
    ${GHCR_IMAGE}:${RELEASE_VERSION}
ExecStop=/usr/bin/docker stop ${DOCKER_CONTAINER_NAME}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT
}

write_config_env() {
    local server_url="$1"
    local auth_token="$2"

    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/config.env" <<ENV
# LockBits EDR Agent configuration
# Generated by install-agent.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
SERVER_URL=${server_url}
AUTH_TOKEN=${auth_token}
AGENT_MODE=${AGENT_MODE:-monitor}
ENV
    chmod 600 "$CONFIG_DIR/config.env"
}

write_config_yaml() {
    local server_url="$1"
    local auth_token="$2"

    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/config.yaml" <<YAML
agent:
  id_file: "${DATA_DIR}/data/agent_id"
  version: "${RELEASE_VERSION}"
  heartbeat_interval: 300
  snapshot_interval: 600
  generate_local_report: false

server:
  url: "${server_url}"
  events_endpoint: "/api/v1/events"
  batch_endpoint: "/api/v1/events/batch"
  heartbeat_endpoint: "/api/v1/heartbeat"
  timeout: 10
  auth_token: "${auth_token}"

queue:
  backend: "jsonl"
  path: "${DATA_DIR}/queue/pending_events.jsonl"
  max_retry: 10

fim:
  watch_dirs:
    linux:
      - /tmp
      - /etc
      - /usr/bin
      - /home

logging:
  level: "${LOG_LEVEL:-INFO}"
  log_file: "${DATA_DIR}/logs/agent.log"
YAML
}

install_binary() {
    local target="$1"
    local arch="$2"
    local version="$3"

    if [ "$version" = "latest" ]; then
        DOWNLOAD_URL="${GH_BASE}/latest/download/${BINARY_NAME}-${target}-${arch}"
    else
        DOWNLOAD_URL="${GH_BASE}/download/v${version}/${BINARY_NAME}-${target}-${arch}"
    fi

    log_info "Downloading ${BINARY_NAME} v${version} (${target}/${arch})..."
    log_info "  ${DOWNLOAD_URL}"

    mkdir -p "$INSTALL_DIR"
    curl -fsSL "$DOWNLOAD_URL" -o "${INSTALL_DIR}/${BINARY_NAME}" || {
        # Try without v prefix if tagged differently
        if [ "$version" != "latest" ]; then
            DOWNLOAD_URL="${GH_BASE}/download/${version}/${BINARY_NAME}-${target}-${arch}"
            curl -fsSL "$DOWNLOAD_URL" -o "${INSTALL_DIR}/${BINARY_NAME}"
        else
            return 1
        fi
    }

    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
    log_info "Binary installed: ${INSTALL_DIR}/${BINARY_NAME}"

    # Verify it runs
    "${INSTALL_DIR}/${BINARY_NAME}" --help &>/dev/null || \
        log_warn "Binary installed but --help check failed. It may still work."
}

install_docker_mode() {
    local server_url="$1"
    local auth_token="$2"

    if [ "$AUTO_INSTALL_DOCKER" = true ] && ! check_docker; then
        install_docker
    fi

    check_docker || fatal "Docker is not installed. Run with --auto-install-docker or install Docker first."

    log_info "Pulling ${GHCR_IMAGE}:${RELEASE_VERSION}..."
    docker pull "${GHCR_IMAGE}:${RELEASE_VERSION}"

    mkdir -p "${DATA_DIR}"/{data,queue,logs}

    log_info "Docker image pulled: ${GHCR_IMAGE}:${RELEASE_VERSION}"
}

reload_systemd() {
    systemctl daemon-reload
}

enable_service() {
    systemctl enable "$SYSTEMD_SERVICE"
    systemctl restart "$SYSTEMD_SERVICE"
    log_info "Service ${SYSTEMD_SERVICE} started and enabled on boot."
}

stop_service() {
    if systemctl is-active --quiet "$SYSTEMD_SERVICE" 2>/dev/null; then
        systemctl stop "$SYSTEMD_SERVICE"
        log_info "Service stopped."
    fi
}

disable_service() {
    if systemctl is-enabled --quiet "$SYSTEMD_SERVICE" 2>/dev/null; then
        systemctl disable "$SYSTEMD_SERVICE"
        log_info "Service disabled."
    fi
}

# ── Parse arguments ──────────────────────────────────────────
MODE="binary"
AUTO_INSTALL_DOCKER=false
DO_UPDATE=false
DO_UNINSTALL=false
DO_STATUS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --auto-install-docker) AUTO_INSTALL_DOCKER=true; shift ;;
        --version) RELEASE_VERSION="$2"; shift 2 ;;
        --update) DO_UPDATE=true; shift ;;
        --uninstall) DO_UNINSTALL=true; shift ;;
        --status) DO_STATUS=true; shift ;;
        --help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

case "$MODE" in
    binary|docker) ;;
    *) fatal "Invalid mode '$MODE'. Must be 'binary' or 'docker'." ;;
esac

# ── Commands ─────────────────────────────────────────────────

# --status: quick check
if [ "$DO_STATUS" = true ]; then
    if systemctl is-active --quiet "$SYSTEMD_SERVICE" 2>/dev/null; then
        echo "LockBits Agent: RUNNING"
        systemctl status "$SYSTEMD_SERVICE" --no-pager 2>&1 | head -20
        exit 0
    fi
    echo "LockBits Agent: NOT RUNNING"
    exit 1
fi

# --uninstall: stop and remove everything
if [ "$DO_UNINSTALL" = true ]; then
    log_info "Uninstalling LockBits EDR Agent..."

    stop_service
    disable_service

    rm -f "/etc/systemd/system/$SYSTEMD_SERVICE"
    systemctl daemon-reload

    if [ -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        rm -f "${INSTALL_DIR}/${BINARY_NAME}"
        log_info "Removed binary: ${INSTALL_DIR}/${BINARY_NAME}"
    fi

    if docker inspect "$DOCKER_CONTAINER_NAME" &>/dev/null 2>&1; then
        docker rm -f "$DOCKER_CONTAINER_NAME" 2>/dev/null || true
    fi

    log_info ""
    log_info "Agent uninstalled."
    log_info "Config (${CONFIG_DIR}/) and data (${DATA_DIR}/) were kept."
    log_info "To remove them manually:"
    log_info "  rm -rf ${CONFIG_DIR}"
    log_info "  rm -rf ${DATA_DIR}"
    exit 0
fi

# --update: re-download / re-pull and restart
if [ "$DO_UPDATE" = true ]; then
    log_info "Updating LockBits EDR Agent..."
    check_root

    if [ "$MODE" = "binary" ]; then
        TARGET="$(detect_os)"
        ARCH="$(detect_arch)"
        install_binary "$TARGET" "$ARCH" "$RELEASE_VERSION"
    else
        check_docker || fatal "Docker is required for --mode docker"
        log_info "Pulling ${GHCR_IMAGE}:${RELEASE_VERSION}..."
        docker pull "${GHCR_IMAGE}:${RELEASE_VERSION}"
    fi

    stop_service
    sleep 1
    enable_service
    log_info "Update complete. Agent restarted."
    exit 0
fi

# ── Install ──────────────────────────────────────────────────
check_root
ensure_server_url
ensure_auth_token

log_info "LockBits EDR Agent — Installer"
log_info "  Mode:       ${MODE}"
log_info "  Server URL: ${SERVER_URL}"
log_info "  Version:    ${RELEASE_VERSION}"
log_info ""

mkdir -p "${DATA_DIR}"/{data,queue,logs}
write_config_env "$SERVER_URL" "$AUTH_TOKEN"

if [ "$MODE" = "binary" ]; then
    TARGET="$(detect_os)"
    ARCH="$(detect_arch)"
    log_info "Detected: ${TARGET}/${ARCH}"

    install_binary "$TARGET" "$ARCH" "$RELEASE_VERSION"
    write_config_yaml "$SERVER_URL" "$AUTH_TOKEN"
    systemd_unit_binary "$SERVER_URL" "$AUTH_TOKEN"

elif [ "$MODE" = "docker" ]; then
    install_docker_mode "$SERVER_URL" "$AUTH_TOKEN"
    systemd_unit_docker "$SERVER_URL" "$AUTH_TOKEN"
fi

reload_systemd
enable_service

# ── Summary ──────────────────────────────────────────────────
log_info ""
log_info "═══════════════════════════════════════════════════"
log_info " LockBits EDR Agent installed successfully!"
log_info "═══════════════════════════════════════════════════"
log_info ""
log_info "  Mode:      ${MODE}"
log_info "  Server:    ${SERVER_URL}"
log_info "  Config:    ${CONFIG_DIR}/"
log_info "  Data:      ${DATA_DIR}/"
log_info "  Service:   ${SYSTEMD_SERVICE}"
if [ "$MODE" = "binary" ]; then
    log_info "  Binary:    ${INSTALL_DIR}/${BINARY_NAME}"
fi
log_info ""
log_info "Commands:"
log_info "  Check status:  sudo systemctl status ${SYSTEMD_SERVICE}"
log_info "  View logs:     sudo journalctl -u ${SYSTEMD_SERVICE} -f"
log_info "  Update:        curl -fsSL ... | bash -s -- --update"
log_info "  Uninstall:     curl -fsSL ... | sudo bash -s -- --uninstall"
log_info ""
