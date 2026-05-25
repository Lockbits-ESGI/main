#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# LockBits — Restore Script
# ─────────────────────────────────────────────────────────────────────────────
# Restores a previously created backup:
#   - MySQL database
#   - PostgreSQL database (if backup exists)
#   - Configuration files (.env, docker-compose*.yml, Caddyfile)
#
# Usage:
#   ./scripts/restore.sh                      # interactive (list + choose)
#   ./scripts/restore.sh 2025-05-25_143022    # restore specific backup
#   ./scripts/restore.sh /path/to/backup/2025-05-25_143022
#
# Environment:
#   BACKUP_DIR   — Where backups are stored (default: ./backups)
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

# ── Resolve project root ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ─────────────────────────────────────────────────────────────────
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
LOG_FILE="$BACKUP_DIR/backup.log"

# Container names (matching docker-compose convention)
MYSQL_CONTAINER="lockbits_db"
PG_CONTAINER="lockbits_edr_db"

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

# ── Logging ──────────────────────────────────────────────────────────────────
log() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" >> "$LOG_FILE"
}

# ── Helper: confirm action ──────────────────────────────────────────────────
confirm() {
    local prompt="$1"
    local reply
    read -rp "$prompt [y/N] " reply
    case "$reply" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# ── Helper: check if a container is running ─────────────────────────────────
container_running() {
    local name="$1"
    docker container inspect "$name" --format '{{.State.Status}}' 2>/dev/null | grep -q 'running'
}

# ── List available backups ───────────────────────────────────────────────────
list_backups() {
    local backups=()
    while IFS= read -r dir; do
        backups+=("$dir")
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name '????-??-??_*' | sort -r)

    if [ ${#backups[@]} -eq 0 ]; then
        echo ""
        warn "No backups found in $BACKUP_DIR"
        echo ""
        exit 1
    fi

    echo ""
    echo "Available backups:"
    echo "------------------"
    local idx=1
    for b in "${backups[@]}"; do
        local size
        size=$(du -sh "$b" 2>/dev/null | cut -f1)
        echo "  $idx) $(basename "$b")  (${size})"
        idx=$((idx + 1))
    done
    echo ""

    # Return array
    BACKUPS_LIST=("${backups[@]}")
}

# ── Resolve backup path from argument or prompt ─────────────────────────────
resolve_backup() {
    local input="${1:-}"

    # If no argument, show list and prompt
    if [ -z "$input" ]; then
        list_backups
        local choice
        read -rp "Select backup to restore [1-${#BACKUPS_LIST[@]}]: " choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#BACKUPS_LIST[@]}" ]; then
            error "Invalid selection"
        fi
        RESTORE_PATH="${BACKUPS_LIST[$((choice - 1))]}"
        return
    fi

    # Check if input is a full path
    if [ -d "$input" ]; then
        RESTORE_PATH="$input"
        return
    fi

    # Check if input is a timestamp (basename)
    if [ -d "$BACKUP_DIR/$input" ]; then
        RESTORE_PATH="$BACKUP_DIR/$input"
        return
    fi

    error "Backup not found: $input (looked in $BACKUP_DIR/$input)"
}

# ── Validate backup contents ────────────────────────────────────────────────
validate_backup() {
    local path="$1"
    local errors=0

    header "Validating backup: $(basename "$path")"

    # Check manifest
    if [ -f "$path/MANIFEST.txt" ]; then
        info "Manifest found"
        cat "$path/MANIFEST.txt"
    else
        warn "No MANIFEST.txt found (backup may be incomplete)"
    fi

    # Check MySQL dump
    local mysql_dump
    mysql_dump=$(find "$path" -name 'mysql_*.sql.gz' | head -1)
    if [ -n "$mysql_dump" ]; then
        info "MySQL dump found: $(basename "$mysql_dump")"
    else
        warn "No MySQL dump found in this backup"
        errors=$((errors + 1))
    fi

    # Check PostgreSQL dump or EDR data
    local pg_dump
    pg_dump=$(find "$path" -name 'postgresql_*.sql.gz' | head -1)
    local edr_data
    edr_data=$(find "$path" -name 'edr_data.tar.gz' | head -1)
    if [ -n "$pg_dump" ]; then
        info "PostgreSQL dump found: $(basename "$pg_dump")"
    elif [ -n "$edr_data" ]; then
        info "EDR data volume found: $(basename "$edr_data")"
    else
        warn "No PostgreSQL dump or EDR data found (may be expected if not configured)"
    fi

    # Check config archive
    if [ -f "$path/config.tar.gz" ]; then
        info "Configuration archive found: config.tar.gz"
    else
        warn "No configuration archive found"
    fi

    echo ""
    if [ "$errors" -gt 0 ]; then
        warn "$errors critical item(s) missing — proceed with caution"
    else
        info "Backup validation passed"
    fi
}

# ── Restore MySQL ───────────────────────────────────────────────────────────
restore_mysql() {
    local backup_path="$1"
    local mysql_dump
    mysql_dump=$(find "$backup_path" -name 'mysql_*.sql.gz' | head -1)

    if [ -z "$mysql_dump" ]; then
        warn "No MySQL dump found — skipping"
        log "WARN" "MySQL restore skipped: no dump file"
        return 1
    fi

    header "Restoring MySQL ($DB_NAME)"

    if ! container_running "$MYSQL_CONTAINER"; then
        error "MySQL container '$MYSQL_CONTAINER' is not running"
    fi

    info "Restoring from: $(basename "$mysql_dump")"
    log "INFO" "Starting MySQL restore from $mysql_dump"

    # Decompress and restore
    if ! gunzip -c "$mysql_dump" | docker exec -i "$MYSQL_CONTAINER" \
        mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>>"$LOG_FILE"; then
        error "MySQL restore failed. Check $LOG_FILE for details."
    fi

    info "MySQL restore completed"
    log "INFO" "MySQL restore completed"
}

# ── Restore PostgreSQL (if dump exists) ─────────────────────────────────────
restore_postgresql() {
    local backup_path="$1"
    local pg_dump
    pg_dump=$(find "$backup_path" -name 'postgresql_*.sql.gz' | head -1)

    if [ -z "$pg_dump" ]; then
        warn "No PostgreSQL dump found — skipping"
        log "WARN" "PostgreSQL restore skipped: no dump file"
        return 1
    fi

    header "Restoring PostgreSQL (${EDR_DB_NAME:-lockbits_edr})"

    if ! container_running "$PG_CONTAINER"; then
        error "PostgreSQL container '$PG_CONTAINER' is not running"
    fi

    info "Restoring from: $(basename "$pg_dump")"
    log "INFO" "Starting PostgreSQL restore from $pg_dump"

    PG_CREDS=""
    [ -n "$EDR_DB_USER" ] && PG_CREDS="$PG_CREDS -U $EDR_DB_USER"
    [ -n "$EDR_DB_NAME" ] && PG_CREDS="$PG_CREDS -d $EDR_DB_NAME"

    if ! gunzip -c "$pg_dump" | docker exec -i "$PG_CONTAINER" \
        psql $PG_CREDS 2>>"$LOG_FILE"; then
        error "PostgreSQL restore failed. Check $LOG_FILE for details."
    fi

    info "PostgreSQL restore completed"
    log "INFO" "PostgreSQL restore completed"
}

# ── Restore EDR data volume (fallback) ──────────────────────────────────────
restore_edr_data() {
    local backup_path="$1"
    local edr_data
    edr_data=$(find "$backup_path" -name 'edr_data.tar.gz' | head -1)

    if [ -z "$edr_data" ]; then
        # Not an error — backup may not have included EDR data
        return 0
    fi

    header "Restoring EDR Data Volume"

    local edr_container="lockbits_edr"
    if ! container_running "$edr_container"; then
        error "EDR container '$edr_container' is not running"
    fi

    info "Restoring from: $(basename "$edr_data")"
    log "INFO" "Starting EDR data restore from $edr_data"

    # Copy archive into container and extract
    docker cp "$edr_data" "$edr_container:/tmp/edr_data_restore.tar.gz" 2>>"$LOG_FILE"
    docker exec "$edr_container" \
        tar xzf /tmp/edr_data_restore.tar.gz -C /app/data 2>>"$LOG_FILE"
    docker exec "$edr_container" rm /tmp/edr_data_restore.tar.gz 2>>"$LOG_FILE"

    info "EDR data volume restore completed"
    log "INFO" "EDR data volume restore completed"
}

# ── Restore configuration files ─────────────────────────────────────────────
restore_config() {
    local backup_path="$1"
    local config_archive="$backup_path/config.tar.gz"

    if [ ! -f "$config_archive" ]; then
        warn "No configuration archive found — skipping"
        log "WARN" "Config restore skipped: no archive"
        return 1
    fi

    header "Restoring Configuration Files"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    tar xzf "$config_archive" -C "$tmp_dir" 2>>"$LOG_FILE"

    local config_dir="$tmp_dir/config"

    # .env
    if [ -f "$config_dir/.env" ]; then
        if confirm "Overwrite current .env with backed-up version?"; then
            cp "$config_dir/.env" "$ENV_FILE"
            info ".env restored"
            log "INFO" ".env restored from backup"
        else
            warn ".env restore skipped"
        fi
    fi

    # docker-compose files
    for f in "$config_dir"/docker-compose*.yml; do
        if [ -f "$f" ]; then
            local base
            base=$(basename "$f")
            if confirm "Overwrite current $base with backed-up version?"; then
                cp "$f" "$PROJECT_ROOT/$base"
                info "$base restored"
                log "INFO" "$base restored from backup"
            else
                warn "$base restore skipped"
            fi
        fi
    done

    # Caddyfile
    if [ -f "$config_dir/Caddyfile" ]; then
        if confirm "Overwrite current Caddyfile with backed-up version?"; then
            cp "$config_dir/Caddyfile" "$PROJECT_ROOT/Caddyfile"
            info "Caddyfile restored"
            log "INFO" "Caddyfile restored from backup"
        else
            warn "Caddyfile restore skipped"
        fi
    fi

    rm -rf "$tmp_dir"
    info "Configuration restore completed"
}

# ── Main ─────────────────────────────────────────────────────────────────────
header "LockBits — Restore"

# Parse argument
RESTORE_PATH=""
resolve_backup "${1:-}"

info "Backup selected: $(basename "$RESTORE_PATH")"

# Validate
validate_backup "$RESTORE_PATH"

# Confirm
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
warn "This will OVERWRITE current databases and configuration files."
echo "  Backup  : $(basename "$RESTORE_PATH")"
echo "  Date    : $(date -r "$RESTORE_PATH" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ! confirm "Proceed with restore?"; then
    echo ""
    warn "Restore cancelled by user"
    log "INFO" "Restore cancelled by user"
    exit 0
fi

log "INFO" "Restore started from: $RESTORE_PATH"

# Execute restores (each checks for file existence internally)
restore_mysql "$RESTORE_PATH"
restore_postgresql "$RESTORE_PATH"
restore_edr_data "$RESTORE_PATH"
restore_config "$RESTORE_PATH"

# Done
echo ""
info "Restore completed successfully from $(basename "$RESTORE_PATH")"
log "INFO" "Restore completed from: $RESTORE_PATH"
