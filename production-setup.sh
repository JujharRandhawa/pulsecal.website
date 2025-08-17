#!/bin/bash

# PulseCal Production Setup Script for Lightsail
# Run this script on your Lightsail server

set -e

echo "🏥 PulseCal Production Setup on AWS Lightsail"
echo "============================================="

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "🔧 Installing required packages..."
sudo apt install -y curl git nginx certbot python3-certbot-nginx

# Install Docker
echo "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
rm get-docker.sh

# Install Docker Compose
echo "📦 Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create application directory
echo "📁 Setting up application directory..."
sudo mkdir -p /opt/pulsecal
sudo chown ubuntu:ubuntu /opt/pulsecal
cd /opt/pulsecal

# Clone repository (replace with your actual repository URL)
echo "📥 Cloning PulseCal repository..."
git clone https://github.com/YOUR_USERNAME/pulsecal.git .

# Create production environment file
echo "⚙️ Setting up production environment..."
cp .env.production.example .env

# Update .env file with production settings
cat > .env << EOF
# Production Environment Configuration for PulseCal

# Environment
ENVIRONMENT=production
DEBUG=False

# Security - CHANGE THESE IN PRODUCTION!
SECRET_KEY=$(openssl rand -base64 32)
ALLOWED_HOSTS=13.200.76.254,pulsecal.com,www.pulsecal.com

# Database Configuration
DB_NAME=pulsecal_prod
DB_USER=pulsecal_user
DB_PASSWORD=$(openssl rand -base64 16)

# CSRF and CORS Settings
CSRF_TRUSTED_ORIGINS=https://pulsecal.com,https://www.pulsecal.com,http://13.200.76.254:8000
CORS_ALLOWED_ORIGINS=https://pulsecal.com,https://www.pulsecal.com,http://13.200.76.254:8000

# Email Configuration
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=noreply@pulsecal.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=PulseCal Healthcare <noreply@pulsecal.com>

# Google OAuth Settings (Optional)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URI=https://pulsecal.com/accounts/google/login/callback/

# Google Maps API (Optional)
GOOGLE_MAPS_API_KEY=
GOOGLE_PLACES_API_KEY=

# Redis Configuration
REDIS_URL=redis://redis:6379/0

# Superuser Configuration
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_EMAIL=admin@pulsecal.com
DJANGO_SUPERUSER_PASSWORD=SecureAdmin123!

# Performance Settings
CONN_MAX_AGE=60
CACHE_TTL=300

# File Upload Settings
FILE_UPLOAD_MAX_MEMORY_SIZE=10485760
DATA_UPLOAD_MAX_MEMORY_SIZE=10485760
EOF

echo "🚀 Deploying PulseCal application..."
chmod +x deploy.sh
./deploy.sh --production

echo ""
echo "🎉 PulseCal deployment completed!"
echo "================================="
echo ""
echo "📊 Access your application:"
echo "  • Main App: http://13.200.76.254:8000"
echo "  • Admin Panel: http://13.200.76.254:8000/admin"
echo ""
echo "👤 Admin Credentials:"
echo "  • Username: admin"
echo "  • Password: SecureAdmin123!"
echo ""
echo "🔒 Next Steps:"
echo "1. Point your domain to: 13.200.76.254"
echo "2. Set up SSL certificate: sudo certbot --nginx -d pulsecal.com -d www.pulsecal.com"
echo "3. Configure email settings in .env file"
echo "4. Set up Google OAuth (optional)"
echo ""
echo "🔧 Useful Commands:"
echo "  • View logs: docker-compose logs -f"
echo "  • Restart: docker-compose restart"
echo "  • Update: git pull && ./deploy.sh --production"