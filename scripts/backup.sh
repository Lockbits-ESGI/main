#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# LockBits — Full Backup Script
# ─────────────────────────────────────────────────────────────────────────────
# Creates timestamped backups of:
#   - MySQL database  (container: lockbits_db)
#   - PostgreSQL DB   (container: lockbits_edr_db, if running)
#   - EDR data volume (fallback if no PostgreSQL container)
#   - Configuration files (.env, docker-compose*.yml, Caddyfile)
#
# Usage:
#   ./scripts/backup.sh                          # default backup dir
#   BACKUP_DIR=/path/to/backups ./scripts/backup.sh
#
# Environment variables (read from .env if present):
#   DB_USER, DB_PASS, DB_NAME          — MySQL credentials
#   EDR_DB_USER, EDR_DB_PASS, EDR_DB_NAME — PostgreSQL credentials
#   BACKUP_DIR                         — Backup destination (default: ./backups)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors (matching install.sh) ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1" >&2; exit 1; }
header(){ echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ── Resolve project root (where this script lives) ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ─────────────────────────────────────────────────────────────────
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
LOG_FILE="$BACKUP_DIR/backup.log"
RETENTION_DAYS=7

# Container names (matching docker-compose convention)
MYSQL_CONTAINER="lockbits_db"
PG_CONTAINER="lockbits_edr_db"
EDR_CONTAINER="lockbits_edr"

# ── Load .env if present ────────────────────────────────────────────────────
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
fi

# ── Database credentials (with defaults) ────────────────────────────────────
DB_USER="${DB_USER:-lockbits}"
DB_PASS="${DB_PASS:-lockbits_password}"
DB_NAME="${DB_NAME:-lockbits_client}"

EDR_DB_USER="${EDR_DB_USER:-}"
EDR_DB_PASS="${EDR_DB_PASS:-}"
EDR_DB_NAME="${EDR_DB_NAME:-}"

# ── Helper: log to both file and stdout ─────────────────────────────────────
log() {
    local level="$1"
    shift
    local msg="$*"
    local prefix
    case "$level" in
        INFO)  prefix="[INFO]"  ;;
        WARN)  prefix="[WARN]"  ;;
        ERROR) prefix="[ERROR]" ;;
        *)     prefix="[INFO]"  ;;
    esac
    echo "$(date '+%Y-%m-%d %H:%M:%S') $prefix $msg" >> "$LOG_FILE"
}

# ── Helper: check if a container is running ─────────────────────────────────
container_running() {
    local name="$1"
    docker container inspect "$name" --format '{{.State.Status}}' 2>/dev/null | grep -q 'running'
}

# ── Sanity checks ───────────────────────────────────────────────────────────
header "Prerequisites"

mkdir -p "$BACKUP_DIR" "$BACKUP_PATH"
log "INFO" "Backup started → $BACKUP_PATH"

if ! command -v docker &>/dev/null; then
    error "Docker is not available"
fi
info "Docker found: $(docker --version | cut -d' ' -f3 | tr -d ',')"

# Check MySQL container
if ! container_running "$MYSQL_CONTAINER"; then
    error "MySQL container '$MYSQL_CONTAINER' is not running. Aborting."
fi
info "MySQL container '$MYSQL_CONTAINER' is running"

# Check PostgreSQL container (optional - preprod/prod only)
PG_AVAILABLE=false
if container_running "$PG_CONTAINER"; then
    PG_AVAILABLE=true
    info "PostgreSQL container '$PG_CONTAINER' is running"
else
    warn "PostgreSQL container '$PG_CONTAINER' not running — skipping pg_dump"
    if [ -n "${EDR_DB_USER:-}" ]; then
        warn "  EDR DB credentials found but container is absent"
    fi
fi

# Check EDR container (for volume fallback)
EDR_AVAILABLE=false
if container_running "$EDR_CONTAINER"; then
    EDR_AVAILABLE=true
    info "EDR container '$EDR_CONTAINER' is running"
fi

# ── 1. Backup MySQL ─────────────────────────────────────────────────────────
header "MySQL Backup ($DB_NAME from $MYSQL_CONTAINER)"

MYSQL_DUMP_FILE="$BACKUP_PATH/mysql_${DB_NAME}.sql"
log "INFO" "Starting MySQL dump: $DB_NAME"

if ! docker exec "$MYSQL_CONTAINER" \
    mysqldump \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    > "$MYSQL_DUMP_FILE" 2>>"$LOG_FILE"; then
    error "MySQL dump failed. Check $LOG_FILE for details."
fi

gzip -f "$MYSQL_DUMP_FILE"
info "MySQL dump completed: ${MYSQL_DUMP_FILE}.gz ($(du -h "${MYSQL_DUMP_FILE}.gz" | cut -f1))"
log "INFO" "MySQL dump saved: ${MYSQL_DUMP_FILE}.gz"

# ── 2. Backup PostgreSQL (if available) ─────────────────────────────────────
if [ "$PG_AVAILABLE" = true ]; then
    header "PostgreSQL Backup (${EDR_DB_NAME:-lockbits_edr} from $PG_CONTAINER)"

    PG_DUMP_FILE="$BACKUP_PATH/postgresql_${EDR_DB_NAME:-lockbits_edr}.sql"
    log "INFO" "Starting PostgreSQL dump"

    PG_CREDS=""
    [ -n "$EDR_DB_USER" ] && PG_CREDS="$PG_CREDS -U $EDR_DB_USER"
    [ -n "$EDR_DB_NAME" ] && PG_CREDS="$PG_CREDS -d $EDR_DB_NAME"

    if ! docker exec "$PG_CONTAINER" \
        pg_dump \
        --clean \
        --if-exists \
        $PG_CREDS \
        > "$PG_DUMP_FILE" 2>>"$LOG_FILE"; then
        error "PostgreSQL dump failed. Check $LOG_FILE for details."
    fi

    gzip -f "$PG_DUMP_FILE"
    info "PostgreSQL dump completed: ${PG_DUMP_FILE}.gz ($(du -h "${PG_DUMP_FILE}.gz" | cut -f1))"
    log "INFO" "PostgreSQL dump saved: ${PG_DUMP_FILE}.gz"
else
    # ── 2b. Fallback: backup EDR data volume via docker cp ──────────────────
    if [ "$EDR_AVAILABLE" = true ]; then
        header "EDR Data Volume Backup (fallback — no PostgreSQL)"

        EDR_DATA_FILE="$BACKUP_PATH/edr_data.tar.gz"
        log "INFO" "Starting EDR data volume backup via docker cp"

        # Create a temporary archive inside the container, then copy it out
        docker exec "$EDR_CONTAINER" \
            tar czf /tmp/edr_data_backup.tar.gz -C /app/data . \
            2>>"$LOG_FILE"

        docker cp "$EDR_CONTAINER:/tmp/edr_data_backup.tar.gz" "$EDR_DATA_FILE" \
            2>>"$LOG_FILE"

        docker exec "$EDR_CONTAINER" rm /tmp/edr_data_backup.tar.gz \
            2>>"$LOG_FILE"

        info "EDR data volume backup completed: $EDR_DATA_FILE ($(du -h "$EDR_DATA_FILE" | cut -f1))"
        log "INFO" "EDR data volume saved: $EDR_DATA_FILE"
    else
        warn "Neither PostgreSQL container nor EDR container is running — EDR data skipped"
        log "WARN" "EDR backup skipped — no container available"
    fi
fi

# ── 3. Backup configuration files ───────────────────────────────────────────
header "Configuration Files Backup"

CONFIG_DIR="$BACKUP_PATH/config"
mkdir -p "$CONFIG_DIR"
log "INFO" "Starting configuration files backup"

# .env
if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" "$CONFIG_DIR/.env"
    info ".env backed up"
    log "INFO" ".env copied"
else
    warn ".env not found — skipping"
    log "WARN" ".env not found"
fi

# docker-compose files
for f in "$PROJECT_ROOT"/docker-compose*.yml; do
    if [ -f "$f" ]; then
        cp "$f" "$CONFIG_DIR/"
        info "Configuration backed up: $(basename "$f")"
        log "INFO" "Copied: $(basename "$f")"
    fi
done

# Caddyfile (if exists)
if [ -f "$PROJECT_ROOT/Caddyfile" ]; then
    cp "$PROJECT_ROOT/Caddyfile" "$CONFIG_DIR/"
    info "Caddyfile backed up"
    log "INFO" "Caddyfile copied"
fi

# Compress config directory
tar czf "$BACKUP_PATH/config.tar.gz" -C "$BACKUP_PATH" config 2>>"$LOG_FILE"
rm -rf "$CONFIG_DIR"
info "Configuration archive: config.tar.gz"
log "INFO" "Configuration archive created"

# ── 4. Create backup manifest ───────────────────────────────────────────────
header "Backup Summary"

MANIFEST="$BACKUP_PATH/MANIFEST.txt"
{
    echo "LockBits Backup Manifest"
    echo "========================"
    echo "Timestamp : $TIMESTAMP"
    echo "Hostname  : $(hostname)"
    echo "Docker    : $(docker --version 2>/dev/null || echo 'N/A')"
    echo ""
    echo "Contents:"
    ls -lh "$BACKUP_PATH/" | grep -v MANIFEST
    echo ""
    echo "Environment:"
    echo "  DB_USER=$DB_USER"
    echo "  DB_NAME=$DB_NAME"
    echo "  EDR_DB_USER=${EDR_DB_USER:-<not set>}"
    echo "  EDR_DB_NAME=${EDR_DB_NAME:-<not set>}"
} > "$MANIFEST"

info "Manifest: MANIFEST.txt"
log "INFO" "Manifest created"

info "Total backup size: $(du -sh "$BACKUP_PATH" | cut -f1)"

# ── 5. Retention — keep last N daily backups ────────────────────────────────
header "Retention"

if [ "$RETENTION_DAYS" -gt 0 ]; then
    # Count existing backup directories
    BACKUP_COUNT=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name '????-??-??_*' | wc -l)
    DELETED=0

    while IFS= read -r old; do
        if [ -n "$old" ]; then
            rm -rf "$old"
            log "INFO" "Removed old backup: $(basename "$old")"
            DELETED=$((DELETED + 1))
        fi
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name '????-??-??_*' -mtime +"$RETENTION_DAYS" 2>/dev/null || true)

    if [ "$DELETED" -gt 0 ]; then
        info "Removed $DELETED backup(s) older than $RETENTION_DAYS days"
    else
        info "No backups to remove (retention: $RETENTION_DAYS days)"
    fi
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
info "Backup completed successfully → $BACKUP_PATH"
log "INFO" "Backup completed: $BACKUP_PATH"
