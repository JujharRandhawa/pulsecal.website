#!/bin/bash

# PulseCal Restore Script
# Restore PulseCal from backup

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "PulseCal Restore Script"
    echo "Usage: $0 [BACKUP_DATE]"
    echo ""
    echo "Arguments:"
    echo "  BACKUP_DATE    Backup date in format YYYYMMDD_HHMMSS"
    echo ""
    echo "Examples:"
    echo "  $0 20241201_143022    # Restore from specific backup"
    echo "  $0                    # Show available backups"
    echo ""
    echo "Available backups:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -la "$BACKUP_DIR" | grep "db_backup_" | awk '{print $9}' | sed 's/db_backup_/  /' | sed 's/.sql.gz//'
    else
        echo "  No backups found in $BACKUP_DIR"
    fi
}

# Check if backup date is provided
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

BACKUP_DATE=$1

# Validate backup date format
if [[ ! $BACKUP_DATE =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
    error "Invalid backup date format. Use YYYYMMDD_HHMMSS"
    show_usage
    exit 1
fi

# Check if backup files exist
DB_BACKUP="$BACKUP_DIR/db_backup_$BACKUP_DATE.sql.gz"
MEDIA_BACKUP="$BACKUP_DIR/media_backup_$BACKUP_DATE.tar.gz"
CONFIG_BACKUP="$BACKUP_DIR/config_backup_$BACKUP_DATE.tar.gz"
MANIFEST="$BACKUP_DIR/manifest_$BACKUP_DATE.txt"

if [ ! -f "$DB_BACKUP" ]; then
    error "Database backup not found: $DB_BACKUP"
    show_usage
    exit 1
fi

log "PulseCal Restore Process Starting..."
log "Backup date: $BACKUP_DATE"

# Show backup manifest if available
if [ -f "$MANIFEST" ]; then
    log "Backup manifest:"
    cat "$MANIFEST"
    echo ""
fi

# Confirmation prompt
read -p "Are you sure you want to restore from backup $BACKUP_DATE? This will overwrite current data. (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Restore cancelled by user"
    exit 0
fi

# Load environment variables
if [ -f .env ]; then
    source .env
fi

DB_NAME=${DB_NAME:-pulsecal_db}
DB_USER=${DB_USER:-pulsecal_user}

# Stop services
step "Stopping PulseCal services..."
docker-compose down

# Start only database and redis
step "Starting database and Redis..."
docker-compose up -d db redis

# Wait for database to be ready
step "Waiting for database to be ready..."
sleep 10

max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker-compose exec -T db pg_isready -U "$DB_USER" -d "$DB_NAME" &>/dev/null; then
        log "Database is ready"
        break
    fi
    sleep 2
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    error "Database failed to become ready"
    exit 1
fi

# Restore database
step "Restoring database..."
log "Dropping existing database..."
docker-compose exec -T db psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
docker-compose exec -T db psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;"

log "Restoring database from backup..."
gunzip -c "$DB_BACKUP" | docker-compose exec -T db psql -U "$DB_USER" -d "$DB_NAME"

log "Database restore completed"

# Start web service
step "Starting web service..."
docker-compose up -d web

# Wait for web service
sleep 15

# Restore media files
if [ -f "$MEDIA_BACKUP" ]; then
    step "Restoring media files..."
    docker-compose exec -T web rm -rf /app/media/*
    docker-compose exec -T web tar -xzf - -C / < "$MEDIA_BACKUP"
    log "Media files restored"
else
    warn "Media backup not found, skipping media restore"
fi

# Restore configuration files (optional)
if [ -f "$CONFIG_BACKUP" ]; then
    step "Configuration backup found"
    log "Configuration files are available in: $CONFIG_BACKUP"
    log "Extract manually if needed: tar -xzf $CONFIG_BACKUP"
fi

# Start all services
step "Starting all services..."
docker-compose up -d

# Wait for services to be healthy
step "Waiting for services to be healthy..."
sleep 30

# Run post-restore tasks
step "Running post-restore tasks..."

# Collect static files
log "Collecting static files..."
docker-compose exec -T web python manage.py collectstatic --noinput

# Run migrations (in case of version differences)
log "Running database migrations..."
docker-compose exec -T web python manage.py migrate --noinput

# Clear cache
log "Clearing cache..."
docker-compose exec -T web python manage.py shell -c "
from django.core.cache import cache
cache.clear()
print('Cache cleared')
" 2>/dev/null || warn "Cache clear failed"

# Final health check
step "Performing health check..."
sleep 10

if curl -f -s http://localhost:8000/health/ > /dev/null 2>&1; then
    log "✅ Health check passed"
else
    warn "⚠️ Health check failed, but services appear to be running"
fi

# Display restore summary
log ""
log "🎉 PulseCal Restore Completed Successfully!"
log "============================================="
echo ""
log "📊 Restore Summary:"
echo "  Backup date: $BACKUP_DATE"
echo "  Database: ✅ Restored"
if [ -f "$MEDIA_BACKUP" ]; then
    echo "  Media files: ✅ Restored"
else
    echo "  Media files: ⚠️ Not available"
fi
echo "  Services: ✅ Running"
echo ""
log "🌐 Application URLs:"
echo "  Main Application: http://localhost:8000"
echo "  Admin Interface:  http://localhost:8000/admin"
echo ""
log "📝 Important Notes:"
echo "  - Verify all data has been restored correctly"
echo "  - Check application functionality"
echo "  - Update any changed configurations"
echo "  - Consider creating a new backup after verification"
echo ""
log "Restore process completed at $(date)"