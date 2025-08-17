#!/bin/bash

# PulseCal Database Reset Script
# This script completely resets the database for fresh deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_error "⚠️  WARNING: This will completely reset the database!"
print_error "⚠️  ALL DATA WILL BE PERMANENTLY LOST!"
echo ""
read -p "Are you sure you want to continue? Type 'RESET' to confirm: " confirmation

if [ "$confirmation" != "RESET" ]; then
    print_status "Database reset cancelled."
    exit 0
fi

print_step "Starting database reset process..."

# Stop all services
print_step "Stopping all services..."
docker-compose down --remove-orphans

# Remove all volumes and data
print_step "Removing all database volumes and data..."
docker volume rm $(docker volume ls -q | grep pulsecal) 2>/dev/null || true
rm -rf data/postgres/* 2>/dev/null || true
rm -rf data/redis/* 2>/dev/null || true
rm -rf data/media/* 2>/dev/null || true

# Clean up Docker system
print_step "Cleaning up Docker system..."
docker system prune -f --volumes

# Remove migration files (keep __init__.py)
print_step "Resetting Django migrations..."
find . -path "*/migrations/*.py" -not -name "__init__.py" -delete 2>/dev/null || true
find . -path "*/migrations/*.pyc" -delete 2>/dev/null || true

# Remove SQLite database if exists
rm -f db.sqlite3 2>/dev/null || true

# Remove compiled Python files
print_step "Cleaning Python cache..."
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Remove logs
print_step "Clearing logs..."
rm -rf logs/* 2>/dev/null || true
mkdir -p logs

# Create fresh data directories
print_step "Creating fresh data directories..."
mkdir -p data/{postgres,redis,media}
mkdir -p {logs,backups,ssl}

print_status "✅ Database and data reset completed!"
print_status "Ready for fresh deployment. Run ./deploy.sh to start."