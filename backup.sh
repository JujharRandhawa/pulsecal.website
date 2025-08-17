#!/bin/bash

# PulseCal Backup Script
# Automated backup solution for PulseCal Healthcare Management System

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups"
DATE=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=30

# Load environment variables
if [ -f .env ]; then
    source .env
fi

DB_NAME=${DB_NAME:-pulsecal_db}
DB_USER=${DB_USER:-pulsecal_user}
DB_PASSWORD=${DB_PASSWORD}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

log "Starting PulseCal backup process..."

# Database backup
log "Backing up database..."
if docker-compose exec -T db pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_DIR/db_backup_$DATE.sql.gz"; then
    log "Database backup completed: db_backup_$DATE.sql.gz"
else
    error "Database backup failed"
    exit 1
fi

# Media files backup
log "Backing up media files..."
if docker-compose exec -T web tar -czf - /app/media > "$BACKUP_DIR/media_backup_$DATE.tar.gz" 2>/dev/null; then
    log "Media files backup completed: media_backup_$DATE.tar.gz"
else
    warn "Media files backup failed or no media files found"
fi

# Static files backup (optional)
log "Backing up static files..."
if docker-compose exec -T web tar -czf - /app/staticfiles > "$BACKUP_DIR/static_backup_$DATE.tar.gz" 2>/dev/null; then
    log "Static files backup completed: static_backup_$DATE.tar.gz"
else
    warn "Static files backup failed"
fi

# Configuration backup
log "Backing up configuration files..."
tar -czf "$BACKUP_DIR/config_backup_$DATE.tar.gz" \
    .env* \
    docker-compose*.yml \
    nginx*.conf \
    redis.conf \
    init-db.sh \
    2>/dev/null || warn "Some configuration files not found"

log "Configuration backup completed: config_backup_$DATE.tar.gz"

# Create backup manifest
log "Creating backup manifest..."
cat > "$BACKUP_DIR/manifest_$DATE.txt" << EOF
PulseCal Backup Manifest
========================
Date: $(date)
Backup ID: $DATE

Files:
- db_backup_$DATE.sql.gz (Database)
- media_backup_$DATE.tar.gz (Media files)
- static_backup_$DATE.tar.gz (Static files)
- config_backup_$DATE.tar.gz (Configuration)

Database Info:
- Name: $DB_NAME
- User: $DB_USER

System Info:
- Hostname: $(hostname)
- Docker Compose Version: $(docker-compose --version)
- Disk Usage: $(df -h .)
EOF

# Cleanup old backups
log "Cleaning up old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "*backup_*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "manifest_*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

# Calculate backup sizes
log "Backup summary:"
echo "  Backup directory: $BACKUP_DIR"
echo "  Backup date: $DATE"
if [ -f "$BACKUP_DIR/db_backup_$DATE.sql.gz" ]; then
    echo "  Database size: $(du -h "$BACKUP_DIR/db_backup_$DATE.sql.gz" | cut -f1)"
fi
if [ -f "$BACKUP_DIR/media_backup_$DATE.tar.gz" ]; then
    echo "  Media size: $(du -h "$BACKUP_DIR/media_backup_$DATE.tar.gz" | cut -f1)"
fi
echo "  Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"

log "Backup process completed successfully!"

# Optional: Upload to cloud storage
if [ -n "${AWS_S3_BUCKET:-}" ]; then
    log "Uploading backups to S3..."
    aws s3 sync "$BACKUP_DIR" "s3://$AWS_S3_BUCKET/pulsecal-backups/" --exclude "*" --include "*$DATE*"
    log "S3 upload completed"
fi

if [ -n "${BACKUP_WEBHOOK_URL:-}" ]; then
    log "Sending backup notification..."
    curl -X POST "$BACKUP_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"PulseCal backup completed successfully at $(date)\"}" \
        2>/dev/null || warn "Webhook notification failed"
fi

log "All backup operations completed!"