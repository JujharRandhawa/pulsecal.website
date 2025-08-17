#!/bin/bash
set -e

# PulseCal Docker Entrypoint Script
# Handles initialization and startup for production containers

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ENTRYPOINT:${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Wait for database to be ready with better error handling
wait_for_db() {
    log "Waiting for database to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if python -c "import django; django.setup(); from django.db import connection; connection.ensure_connection()" > /dev/null 2>&1; then
            log "Database is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        warn "Database not ready (attempt $attempt/$max_attempts), waiting 3 seconds..."
        sleep 3
    done
    
    error "Database failed to become ready after $max_attempts attempts"
    return 1
}

# Wait for Redis to be ready with better error handling
wait_for_redis() {
    log "Waiting for Redis to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if python -c "import redis; r=redis.from_url('${REDIS_URL}'); r.ping()" > /dev/null 2>&1; then
            log "Redis is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        warn "Redis not ready (attempt $attempt/$max_attempts), waiting 3 seconds..."
        sleep 3
    done
    
    error "Redis failed to become ready after $max_attempts attempts"
    return 1
}

# Run database migrations with retry logic
run_migrations() {
    log "Running database migrations..."
    local max_attempts=3
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if python manage.py migrate --noinput; then
            log "Migrations completed successfully"
            return 0
        fi
        
        attempt=$((attempt + 1))
        warn "Migration attempt $attempt failed, retrying..."
        sleep 5
    done
    
    error "Migrations failed after $max_attempts attempts"
    return 1
}

# Collect static files with error handling
collect_static() {
    log "Collecting static files..."
    if python manage.py collectstatic --noinput --clear; then
        log "Static files collected successfully"
    else
        warn "Static files collection failed, but continuing..."
    fi
}

# Create superuser if needed with better error handling
create_superuser() {
    log "Checking for superuser..."
    
    # Check if any superuser exists
    if ! python manage.py shell -c "from django.contrib.auth.models import User; print(User.objects.filter(is_superuser=True).exists())" 2>/dev/null | grep -q "True"; then
        if [ -n "${DJANGO_SUPERUSER_USERNAME:-}" ] && [ -n "${DJANGO_SUPERUSER_EMAIL:-}" ] && [ -n "${DJANGO_SUPERUSER_PASSWORD:-}" ]; then
            log "Creating superuser: ${DJANGO_SUPERUSER_USERNAME}"
            if python manage.py createsuperuser --noinput 2>/dev/null; then
                log "Superuser created successfully"
            else
                warn "Failed to create superuser via environment variables"
                # Fallback: create default admin user
                python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@pulsecal.com', 'admin123')
    print('Default admin user created: admin/admin123')
else:
    print('Admin user already exists')
" 2>/dev/null || warn "Could not create any superuser"
            fi
        else
            warn "No superuser found, creating default admin user..."
            python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@pulsecal.com', 'admin123')
    print('Default admin user created: admin/admin123')
else:
    print('Admin user already exists')
" 2>/dev/null || warn "Could not create default admin user"
        fi
    else
        log "Superuser already exists"
    fi
}

# Setup Google OAuth with error handling
setup_oauth() {
    if [ -n "${GOOGLE_CLIENT_ID:-}" ] && [ -n "${GOOGLE_CLIENT_SECRET:-}" ]; then
        log "Setting up Google OAuth..."
        if python manage.py setup_google_oauth 2>/dev/null; then
            log "Google OAuth configured successfully"
        else
            warn "Google OAuth setup failed, but continuing..."
        fi
    else
        warn "Google OAuth credentials not found, skipping setup"
    fi
}

# Warm up the application
warmup_app() {
    log "Warming up application..."
    python -c "
import django
django.setup()
from django.core.cache import cache
from django.db import connection
# Test database connection
with connection.cursor() as cursor:
    cursor.execute('SELECT 1')
# Test cache
cache.set('warmup', 'ok', 30)
print('Application warmed up successfully')
" 2>/dev/null || warn "Application warmup failed"
}

# Main execution with comprehensive error handling
main() {
    log "Starting PulseCal initialization..."
    
    # Change to app directory
    cd /app
    
    # Set proper permissions
    chmod -R 755 /app/staticfiles /app/media /app/logs 2>/dev/null || true
    
    # Wait for dependencies
    if ! wait_for_db; then
        error "Database initialization failed"
        exit 1
    fi
    
    if ! wait_for_redis; then
        error "Redis initialization failed"
        exit 1
    fi
    
    # Initialize application
    if ! run_migrations; then
        error "Database migrations failed"
        exit 1
    fi
    
    collect_static  # Non-critical, continue on failure
    create_superuser  # Non-critical, continue on failure
    setup_oauth  # Non-critical, continue on failure
    warmup_app  # Non-critical, continue on failure
    
    log "Initialization completed successfully!"
    
    # Execute the main command
    log "Starting application: $*"
    exec "$@"
}

# Handle different startup scenarios
if [ "$1" = "celery" ]; then
    log "Starting Celery worker/beat - skipping full initialization"
    cd /app
    wait_for_db || exit 1
    wait_for_redis || exit 1
    exec "$@"
else
    # Run full initialization for web server
    main "$@"
fi