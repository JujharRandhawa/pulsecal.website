#!/bin/bash

# PulseCal Fresh Production Deployment Script
# Complete fresh deployment with database reset

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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "🏥 PulseCal Fresh Production Deployment"
print_status "======================================"

# Make scripts executable
chmod +x reset-database.sh deploy.sh

# Reset database and clean environment
print_step "Resetting database and cleaning environment..."
./reset-database.sh

# Check if .env exists, if not create from template
if [ ! -f .env ]; then
    print_step "Creating production environment file..."
    cp .env.production.example .env
    print_warning "Please edit .env file with your production settings before continuing!"
    print_warning "Required settings: SECRET_KEY, DB_PASSWORD, ALLOWED_HOSTS"
    read -p "Press Enter after configuring .env file..."
fi

# Validate environment
print_step "Validating environment configuration..."
source .env

if [ -z "${SECRET_KEY:-}" ] || [ "$SECRET_KEY" = "your-super-secret-key-here-change-this-in-production" ]; then
    print_error "Please set a secure SECRET_KEY in .env file"
    exit 1
fi

if [ -z "${DB_PASSWORD:-}" ] || [ "$DB_PASSWORD" = "your-secure-database-password" ]; then
    print_error "Please set a secure DB_PASSWORD in .env file"
    exit 1
fi

if [ -z "${ALLOWED_HOSTS:-}" ]; then
    print_error "Please set ALLOWED_HOSTS in .env file"
    exit 1
fi

print_status "Environment validation passed"

# Deploy fresh system
print_step "Starting fresh deployment..."
./deploy.sh --production --skip-backup

print_status ""
print_status "🎉 Fresh PulseCal Deployment Completed!"
print_status "======================================"
print_status ""
print_status "✅ Database: Fresh and clean"
print_status "✅ Migrations: Applied"
print_status "✅ Static files: Collected"
print_status "✅ Services: Running"
print_status ""
print_status "🔐 Default Admin Account:"
print_status "   Username: admin"
print_status "   Email: admin@pulsecal.com"
print_status "   Password: admin123"
print_warning "   ⚠️  CHANGE THIS PASSWORD IMMEDIATELY!"
print_status ""
print_status "🌐 Access URLs:"
print_status "   Application: http://localhost:8000"
print_status "   Admin Panel: http://localhost:8000/admin"
print_status "   Health Check: http://localhost:8000/health/"
print_status ""
print_status "📋 Next Steps:"
print_status "1. Change admin password immediately"
print_status "2. Configure Google OAuth credentials"
print_status "3. Set up email SMTP settings"
print_status "4. Configure Google Maps API keys"
print_status "5. Test all functionality"
print_status ""
print_status "🚀 Ready for production deployment!"