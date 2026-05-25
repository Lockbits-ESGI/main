# LockBits — Backup & Disaster Recovery

## Overview

This directory contains the backup and restore scripts for the LockBits
infrastructure. They provide a consistent, automated way to protect your data
and recover from failures.

### What gets backed up

| Component     | Container          | Method                    | Format        |
|---------------|--------------------|---------------------------|---------------|
| MySQL (site)  | `lockbits_db`      | `docker exec` + mysqldump | `.sql.gz`     |
| PostgreSQL    | `lockbits_edr_db`  | `docker exec` + pg_dump   | `.sql.gz`     |
| EDR data      | `lockbits_edr`     | `docker cp` + tar (fallback when no PostgreSQL) | `.tar.gz` |
| Config files  | —                  | direct file copy          | `.tar.gz`     |

Configuration files include `.env`, all `docker-compose*.yml` files, and
`Caddyfile` (if present).

---

## Backup Strategy

### Schedule

Run `backup.sh` daily via cron. Example (daily at 02:00):

```bash
0 2 * * * cd /opt/lockbits && ./scripts/backup.sh >> /opt/lockbits/backups/backup.log 2>&1
```

### Rotation

- Backups are stored in timestamped folders: `YYYY-MM-DD_HHMMSS/`
- Only the **last 7 daily backups** are kept — older ones are removed automatically
- Retention is configurable via the script (modify `RETENTION_DAYS`)

### Storage

- Default backup directory: `./backups/` (relative to project root)
- Override with `BACKUP_DIR` environment variable
- Each backup contains a `MANIFEST.txt` with metadata (timestamp, hostname,
  docker version, DB credentials used)

### Security

- **No passwords stored in scripts** — credentials are read from `.env` or
  prompted interactively
- Backups of `.env` contain credentials — **secure the backup directory**
  (e.g., `chmod 700 backups/`, encrypt offsite copies)

---

## Usage

### Backup

```bash
# Default backup (stored in ./backups/)
./scripts/backup.sh

# Custom directory
BACKUP_DIR=/mnt/nas/lockbits-backups ./scripts/backup.sh

# From a different working directory
/opt/lockbits/scripts/backup.sh
```

The script will:
1. Check that Docker and required containers are running
2. Dump MySQL (`lockbits_db`) with `--single-transaction --routines --triggers --events`
3. Dump PostgreSQL (`lockbits_edr_db`) if the container is running
4. Fall back to backing up EDR data volume (`lockbits_edr`) if no PostgreSQL
5. Copy configuration files into the archive
6. Create a manifest with backup metadata
7. Remove backups older than 7 days
8. Log every operation to `backups/backup.log`

### Restore

```bash
# Interactive — list backups and select
./scripts/restore.sh

# Restore a specific backup by timestamp
./scripts/restore.sh 2025-05-25_143022

# Restore from a full path
./scripts/restore.sh /mnt/nas/lockbits-backups/2025-05-25_143022
```

The restore process:
1. Lists available backups and lets you choose (or accepts a path/timestamp)
2. Validates the backup contents (checks for manifest, DB dumps, config)
3. Prompts for confirmation before making any changes
4. Restores MySQL by piping the decompressed dump directly into `mysql`
5. Restores PostgreSQL by piping into `psql`
6. Restores EDR data volume (if present in backup)
7. Restores configuration files with individual prompts for each file
8. Logs every operation

**Important:** Restore will **overwrite** current databases and configuration
files. Confirm only when you are sure.

---

## Recovery Procedures

### Scenario 1: Database corruption (MySQL)

```bash
# 1. Stop the web server to prevent writes
docker stop lockbits_web

# 2. Find the latest backup
./scripts/restore.sh

# 3. Select the backup and confirm
# 4. Restart the web server
docker start lockbits_web
```

### Scenario 2: Full server recovery

```bash
# 1. Deploy the stack fresh (see README.md at project root)
curl -fsSL https://raw.githubusercontent.com/Lockbits-ESGI/main/main/install.sh | bash

# 2. Copy your backup archive to the server
scp backups/2025-05-25_143022 user@new-server:/opt/lockbits/backups/

# 3. Restore everything
cd /opt/lockbits
./scripts/restore.sh 2025-05-25_143022

# 4. Restart any services that depend on the restored data
docker restart lockbits_web lockbits_edr
```

### Scenario 3: Accidental data deletion

```bash
# 1. Immediately stop containers writing to the affected database
docker stop lockbits_web

# 2. Restore just the affected database
./scripts/restore.sh 2025-05-25_143022
# → only confirm MySQL restore, skip config

# 3. Restart services
docker start lockbits_web
```

### Scenario 4: Restore individual files only (no DB)

If you only need configuration files restored, run `restore.sh` and decline
the database restore prompts. Each config file is prompted individually so you
can pick only what you need.

---

## File Reference

| File             | Purpose                                              |
|------------------|------------------------------------------------------|
| `backup.sh`      | Creates timestamped, compressed backups              |
| `restore.sh`     | Lists, validates, and restores from backups          |
| `backups/`       | Default storage directory (gitignored)               |
| `backups/backup.log` | Operation log for all backup/restore actions     |

## Environment Variables

| Variable         | Default              | Description                     |
|------------------|----------------------|---------------------------------|
| `BACKUP_DIR`     | `./backups`          | Backup storage directory        |
| `DB_USER`        | `lockbits`           | MySQL user                      |
| `DB_PASS`        | `lockbits_password`  | MySQL password                  |
| `DB_NAME`        | `lockbits_client`    | MySQL database name             |
| `EDR_DB_USER`    | _(from .env)_        | PostgreSQL user                 |
| `EDR_DB_PASS`    | _(from .env)_        | PostgreSQL password             |
| `EDR_DB_NAME`    | _(from .env)_        | PostgreSQL database name        |

> All variables are read from `.env` if present, with sensible fallback
> defaults for development.
