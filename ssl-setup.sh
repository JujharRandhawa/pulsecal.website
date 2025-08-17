#!/bin/bash

# SSL Certificate Setup for pulsecal.com
# This script sets up SSL certificates using Let's Encrypt

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

print_status "Setting up SSL certificates for pulsecal.com"

# Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    print_status "Installing certbot..."
    apt update
    apt install -y certbot
fi

# Stop any services using port 80
print_status "Stopping services on port 80..."
systemctl stop nginx 2>/dev/null || true
docker-compose down 2>/dev/null || true

# Generate certificates
print_status "Generating SSL certificates..."
certbot certonly --standalone \
    -d pulsecal.com \
    -d www.pulsecal.com \
    --email admin@pulsecal.com \
    --agree-tos \
    --non-interactive

# Create SSL directory
print_status "Setting up SSL directory..."
mkdir -p ssl
chown $SUDO_USER:$SUDO_USER ssl

# Copy certificates
print_status "Copying certificates..."
cp /etc/letsencrypt/live/pulsecal.com/fullchain.pem ssl/cert.pem
cp /etc/letsencrypt/live/pulsecal.com/privkey.pem ssl/key.pem
chown $SUDO_USER:$SUDO_USER ssl/*

# Set up auto-renewal
print_status "Setting up auto-renewal..."
cat > /etc/cron.d/certbot-pulsecal << EOF
# Renew SSL certificates for pulsecal.com
0 12 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx || docker-compose restart nginx"
EOF

print_status "SSL setup completed successfully!"
print_status "Certificates are valid for 90 days and will auto-renew"
print_status "Certificate files:"
echo "  - ssl/cert.pem"
echo "  - ssl/key.pem"

# Verify certificates
print_status "Verifying certificates..."
openssl x509 -in ssl/cert.pem -text -noout | grep -E "(Subject:|DNS:)"

print_status "You can now start your application with HTTPS support"