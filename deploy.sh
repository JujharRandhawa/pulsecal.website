#!/bin/bash

# PulseCal Production Deployment Script
# This script automates the deployment of the PulseCal Healthcare Management System

set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/deployment.log"
BACKUP_DIR="${SCRIPT_DIR}/backups"
DATE=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "Deployment failed with exit code $exit_code"
        print_error "Check the log file: $LOG_FILE"
    fi
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --production)
            ENVIRONMENT=production
            shift
            ;;
        --help)
            echo "PulseCal Deployment Script"
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-backup    Skip backup creation"
            echo "  --production     Force production environment"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create necessary directories
mkdir -p "$BACKUP_DIR" logs data/postgres data/redis data/media ssl

# Initialize log file
log "Starting PulseCal deployment process"
print_status "PulseCal Healthcare Management System - Production Deployment"
print_status "Log file: $LOG_FILE"

# Check if .env file exists
if [ ! -f .env ]; then
    print_error ".env file not found. Please create one from .env.production.example"
    print_error "Copy .env.production.example to .env and configure your settings"
    exit 1
fi

# Load and validate environment variables
print_step "Loading environment configuration..."
source .env

# Validate critical environment variables
required_vars=("SECRET_KEY" "DB_PASSWORD" "ALLOWED_HOSTS")
for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        print_error "Required environment variable $var is not set"
        exit 1
    fi
done

print_status "Environment configuration loaded successfully"

# Check system requirements
print_step "Checking system requirements..."

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    print_error "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    print_error "Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check Docker daemon
if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running. Please start Docker first."
    exit 1
fi

# Check available disk space (minimum 2GB)
available_space=$(df . | awk 'NR==2 {print $4}')
if [ "$available_space" -lt 2097152 ]; then
    print_warning "Low disk space detected. Ensure at least 2GB free space for deployment."
fi

print_status "System requirements check passed"

# Backup existing data if containers are running
if [ "${SKIP_BACKUP:-false}" != "true" ]; then
    print_step "Backing up existing data..."
    if docker-compose ps | grep -q "Up"; then
        print_status "Creating backup of existing data..."
        
        # Backup database
        if docker-compose exec -T db pg_dump -U "${DB_USER:-pulsecal_user}" "${DB_NAME:-pulsecal_db}" > "$BACKUP_DIR/db_backup_$DATE.sql" 2>/dev/null; then
            print_status "Database backup created: $BACKUP_DIR/db_backup_$DATE.sql"
        else
            print_warning "Database backup failed or no existing database found"
        fi
        
        # Backup media files
        if docker-compose exec -T web tar -czf - /app/media 2>/dev/null > "$BACKUP_DIR/media_backup_$DATE.tar.gz"; then
            print_status "Media files backup created: $BACKUP_DIR/media_backup_$DATE.tar.gz"
        else
            print_warning "Media files backup failed or no existing media found"
        fi
    fi
fi

# Stop existing containers
print_step "Stopping existing containers..."
docker-compose down --remove-orphans

# Clean up unused Docker resources
print_step "Cleaning up Docker resources..."
docker system prune -f --volumes

# Build and start services
print_step "Building and starting services..."
if [ "${ENVIRONMENT:-}" = "production" ]; then
    docker-compose -f docker-compose.yml build --no-cache
    docker-compose -f docker-compose.yml up -d
else
    docker-compose build --no-cache
    docker-compose up -d
fi

# Wait for services to be healthy
print_step "Waiting for services to be healthy..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker-compose ps | grep -q "healthy\|Up"; then
        print_status "Services are starting up... (attempt $((attempt + 1))/$max_attempts)"
        break
    fi
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    print_error "Services failed to start within expected time. Check logs:"
    docker-compose logs --tail=50
    exit 1
fi

print_status "Services are running"

# Wait for database to be ready
print_step "Waiting for database to be ready..."
max_db_attempts=30
db_attempt=0

while [ $db_attempt -lt $max_db_attempts ]; do
    if docker-compose exec -T db pg_isready -U "${DB_USER:-pulsecal_user}" -d "${DB_NAME:-pulsecal_db}" &>/dev/null; then
        print_status "Database is ready"
        break
    fi
    sleep 2
    db_attempt=$((db_attempt + 1))
done

if [ $db_attempt -eq $max_db_attempts ]; then
    print_error "Database failed to become ready"
    exit 1
fi

# Run database migrations
print_step "Running database migrations..."
if ! docker-compose exec -T web python manage.py migrate --noinput; then
    print_error "Database migrations failed"
    exit 1
fi
print_status "Database migrations completed"

# Collect static files
print_step "Collecting static files..."
if ! docker-compose exec -T web python manage.py collectstatic --noinput; then
    print_error "Static files collection failed"
    exit 1
fi
print_status "Static files collected"

# Set up Google OAuth
print_step "Setting up Google OAuth..."
if [ -n "${GOOGLE_CLIENT_ID:-}" ] && [ -n "${GOOGLE_CLIENT_SECRET:-}" ]; then
    docker-compose exec -T web python manage.py setup_google_oauth
    print_status "Google OAuth configured"
else
    print_warning "Google OAuth credentials not found. Skipping OAuth setup."
fi

# Create superuser if it doesn't exist
print_step "Checking for superuser..."
if ! docker-compose exec -T web python manage.py shell -c "from django.contrib.auth.models import User; print(User.objects.filter(is_superuser=True).exists())" 2>/dev/null | grep -q "True"; then
    print_warning "No superuser found. Creating default admin user..."
    print_warning "Please change the default password after first login!"
    docker-compose exec -T web python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@pulsecal.com', 'admin123')
    print('Default admin user created: admin/admin123')
else:
    print('Admin user already exists')
" 2>/dev/null || print_warning "Could not create default admin user"
fi

# Final comprehensive health check
print_step "Performing comprehensive health check..."
sleep 30  # Give more time for services to fully start

# Check if all containers are running
print_status "Checking container status..."
docker-compose ps

# Wait for web service to be fully ready
max_health_attempts=20
health_attempt=0
health_check_passed=false

while [ $health_attempt -lt $max_health_attempts ]; do
    print_status "Health check attempt $((health_attempt + 1))/$max_health_attempts..."
    
    # Try multiple health check endpoints
    for endpoint in "http://localhost:8000/health/" "http://127.0.0.1:8000/health/" "http://localhost/health/"; do
        if curl -f -s -m 10 "$endpoint" | grep -q '"status".*"healthy"'; then
            print_status "✓ Health check passed: $endpoint"
            health_check_passed=true
            break 2
        fi
    done
    
    health_attempt=$((health_attempt + 1))
    sleep 10
done

if [ "$health_check_passed" = false ]; then
    print_warning "Health check failed after $max_health_attempts attempts"
    print_warning "Checking service logs for issues..."
    docker-compose logs --tail=20 web
    print_warning "You may need to check the application manually"
else
    print_status "✓ All health checks passed successfully!"
fi

# Display deployment summary
print_status ""
print_status "🎉 PulseCal Healthcare Management System Deployment Completed!"
print_status "==============================================================="
print_status ""
print_status "📊 Deployment Summary:"
print_status "  • Environment: ${ENVIRONMENT:-production}"
print_status "  • Database: PostgreSQL (${DB_NAME:-pulsecal_db})"
print_status "  • Cache: Redis"
print_status "  • Web Server: Gunicorn + Nginx"
print_status "  • Task Queue: Celery"
print_status ""
print_status "🌐 Access URLs:"
print_status "  • Main Application: http://localhost:8000"
print_status "  • Admin Interface: http://localhost:8000/admin"
print_status "  • Health Check: http://localhost:8000/health/"
print_status ""
print_status "👤 Default Admin Credentials:"
print_status "  • Username: admin"
print_status "  • Password: admin123"
print_status "  • Email: admin@pulsecal.com"
print_status ""
print_status "⚠️  IMPORTANT SECURITY NOTES:"
print_status "  • Change default admin password immediately"
print_status "  • Update SECRET_KEY in .env file"
print_status "  • Configure proper ALLOWED_HOSTS for production"
print_status "  • Set up SSL/TLS certificates"
print_status ""
print_status "🔧 Useful Commands:"
print_status "  • View logs: docker-compose logs -f"
print_status "  • Restart: docker-compose restart"
print_status "  • Stop: docker-compose down"
print_status "  • Update: git pull && ./deploy.sh"
print_status ""
if [ "$health_check_passed" = true ]; then
    print_status "✅ Status: HEALTHY - Ready for use!"
else
    print_status "⚠️  Status: NEEDS ATTENTION - Check logs"
fi
print_status "==============================================================="
print_status "📋 Deployment Log: $LOG_FILE"
print_status "📁 Backup Directory: $BACKUP_DIR"
print_status "🕒 Deployment Time: $(date)"
log "Deployment completed at $(date)"