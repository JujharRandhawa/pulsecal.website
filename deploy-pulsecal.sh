#!/bin/bash

# PulseCal.com Production Deployment Script
# Optimized deployment for pulsecal.com domain

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_status "🏥 PulseCal.com Production Deployment"
print_status "====================================="

# Check if running on correct server
print_step "Verifying deployment environment..."
if [ ! -f ".env.pulsecal.com" ]; then
    echo "Creating production environment file..."
    cp .env.pulsecal.com .env
fi

# Load environment
source .env

# Verify domain configuration
print_step "Verifying domain configuration..."
if [[ "$ALLOWED_HOSTS" == *"pulsecal.com"* ]]; then
    print_status "✅ Domain configuration verified"
else
    echo "❌ Domain not configured correctly"
    exit 1
fi

# Check SSL certificates
print_step "Checking SSL certificates..."
if [ -f "ssl/cert.pem" ] && [ -f "ssl/key.pem" ]; then
    print_status "✅ SSL certificates found"
    
    # Check certificate validity
    if openssl x509 -in ssl/cert.pem -noout -checkend 86400; then
        print_status "✅ SSL certificates are valid"
    else
        echo "⚠️ SSL certificates expire soon - consider renewal"
    fi
else
    echo "❌ SSL certificates not found"
    echo "Run: sudo ./ssl-setup.sh"
    exit 1
fi

# Deploy with production configuration
print_step "Deploying PulseCal.com..."
docker-compose -f docker-compose.prod.yml down --remove-orphans
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d

# Wait for services
print_step "Waiting for services to start..."
sleep 30

# Health check
print_step "Performing health check..."
if curl -f -s https://pulsecal.com/health/ > /dev/null 2>&1; then
    print_status "✅ HTTPS health check passed"
elif curl -f -s http://localhost:8000/health/ > /dev/null 2>&1; then
    print_status "✅ Local health check passed"
else
    echo "❌ Health check failed"
    docker-compose -f docker-compose.prod.yml logs --tail=20
    exit 1
fi

# Final setup
print_step "Running final setup..."
docker-compose -f docker-compose.prod.yml exec -T web python manage.py migrate --noinput
docker-compose -f docker-compose.prod.yml exec -T web python manage.py collectstatic --noinput
docker-compose -f docker-compose.prod.yml exec -T web python manage.py setup_google_oauth

print_status ""
print_status "🎉 PulseCal.com Deployment Completed!"
print_status "===================================="
print_status "🌐 Live URL: https://pulsecal.com"
print_status "🔧 Admin:   https://pulsecal.com/admin"
print_status ""
print_status "📊 Service Status:"
docker-compose -f docker-compose.prod.yml ps

print_status ""
print_status "🔍 Quick Commands:"
echo "  View logs:    docker-compose -f docker-compose.prod.yml logs -f"
echo "  Restart:      docker-compose -f docker-compose.prod.yml restart"
echo "  Stop:         docker-compose -f docker-compose.prod.yml down"
echo "  SSL renewal:  sudo ./ssl-setup.sh"