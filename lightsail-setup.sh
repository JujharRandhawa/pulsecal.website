#!/bin/bash

# PulseCal Lightsail Setup Script
# Optimized for 512MB RAM, 2 vCPUs, 20GB SSD

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_status "🏥 PulseCal Lightsail Setup (512MB RAM)"
print_status "======================================"

# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    print_error "This script is designed for Ubuntu. Detected: $(cat /etc/os-release | grep PRETTY_NAME)"
    exit 1
fi

print_status "✅ Ubuntu detected"

# Update system
print_step "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Install essential packages
print_step "Installing essential packages..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    htop \
    nano \
    certbot \
    python3-certbot-nginx \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker
print_step "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
print_step "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Start and enable Docker
print_step "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
print_step "Adding user to docker group..."
sudo usermod -aG docker $USER

# Create swap file for low memory instance
print_step "Creating swap file for memory optimization..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    print_status "✅ 1GB swap file created"
else
    print_status "✅ Swap file already exists"
fi

# Optimize system for low memory
print_step "Optimizing system for low memory..."
cat << 'EOF' | sudo tee /etc/sysctl.d/99-pulsecal.conf
# Memory optimization for 512MB instance
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
net.core.rmem_default=262144
net.core.rmem_max=16777216
net.core.wmem_default=262144
net.core.wmem_max=16777216
EOF

sudo sysctl -p /etc/sysctl.d/99-pulsecal.conf

# Create application directory
print_step "Creating application directory..."
sudo mkdir -p /opt/pulsecal
sudo chown $USER:$USER /opt/pulsecal
cd /opt/pulsecal

# Clone or copy application files
print_step "Setting up application files..."
if [ ! -f docker-compose.lightsail.yml ]; then
    print_warning "Application files not found. Please upload your PulseCal files to /opt/pulsecal"
    print_status "Required files:"
    print_status "- docker-compose.lightsail.yml"
    print_status "- nginx.lightsail.conf"
    print_status "- .env (production configuration)"
    print_status "- All application source code"
fi

# Create environment file template
print_step "Creating environment template..."
cat > .env.lightsail << 'EOF'
# PulseCal Lightsail Environment (512MB RAM)
ENVIRONMENT=production
DEBUG=False

# Security - CHANGE THESE!
SECRET_KEY=your-unique-secret-key-change-this
ALLOWED_HOSTS=your-domain.com,www.your-domain.com

# Database (optimized for low memory)
DB_NAME=pulsecal_db
DB_USER=pulsecal_user
DB_PASSWORD=secure-password-change-this

# CSRF and CORS
CSRF_TRUSTED_ORIGINS=https://your-domain.com,https://www.your-domain.com
CORS_ALLOWED_ORIGINS=https://your-domain.com,https://www.your-domain.com

# Email
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=noreply@your-domain.com
EMAIL_HOST_PASSWORD=your-email-app-password
DEFAULT_FROM_EMAIL=PulseCal <noreply@your-domain.com>

# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=https://your-domain.com/accounts/google/login/callback/

# Google Maps
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
GOOGLE_PLACES_API_KEY=your-google-places-api-key

# Superuser
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_EMAIL=admin@your-domain.com
DJANGO_SUPERUSER_PASSWORD=secure-admin-password
EOF

# Create directories
print_step "Creating application directories..."
mkdir -p {data,logs,backups,ssl}
mkdir -p data/{postgres,redis,media}

# Set up log rotation
print_step "Setting up log rotation..."
sudo tee /etc/logrotate.d/pulsecal << 'EOF'
/opt/pulsecal/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
    postrotate
        cd /opt/pulsecal && docker-compose -f docker-compose.lightsail.yml restart web nginx
    endscript
}
EOF

# Create systemd service
print_step "Creating systemd service..."
sudo tee /etc/systemd/system/pulsecal.service << 'EOF'
[Unit]
Description=PulseCal Healthcare Management System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/pulsecal
ExecStart=/usr/local/bin/docker-compose -f docker-compose.lightsail.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.lightsail.yml down
TimeoutStartSec=300
User=ubuntu
Group=docker

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable pulsecal.service

# Create deployment script
print_step "Creating deployment script..."
cat > deploy-lightsail.sh << 'EOF'
#!/bin/bash
set -e

echo "🏥 Deploying PulseCal on Lightsail..."

# Stop services
docker-compose -f docker-compose.lightsail.yml down

# Clean up to free memory
docker system prune -f

# Build and start
docker-compose -f docker-compose.lightsail.yml build --no-cache
docker-compose -f docker-compose.lightsail.yml up -d

# Wait for services
echo "Waiting for services to start..."
sleep 60

# Run migrations
docker-compose -f docker-compose.lightsail.yml exec -T web python manage.py migrate --noinput

# Collect static files
docker-compose -f docker-compose.lightsail.yml exec -T web python manage.py collectstatic --noinput

# Create superuser if needed
docker-compose -f docker-compose.lightsail.yml exec -T web python manage.py shell -c "
from django.contrib.auth.models import User
if not User.objects.filter(is_superuser=True).exists():
    User.objects.create_superuser('admin', 'admin@pulsecal.com', 'admin123')
    print('Admin user created: admin/admin123')
"

echo "✅ Deployment completed!"
echo "🌐 Access your application at: http://$(curl -s ifconfig.me)"
EOF

chmod +x deploy-lightsail.sh

# Create SSL setup script
print_step "Creating SSL setup script..."
cat > setup-ssl-lightsail.sh << 'EOF'
#!/bin/bash
set -e

echo "🔒 Setting up SSL for PulseCal..."

# Stop nginx
docker-compose -f docker-compose.lightsail.yml stop nginx

# Get certificates
sudo certbot certonly --standalone \
    -d your-domain.com \
    -d www.your-domain.com \
    --email admin@your-domain.com \
    --agree-tos \
    --non-interactive

# Copy certificates
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ssl/key.pem
sudo chown ubuntu:ubuntu ssl/*.pem

# Start nginx with SSL
docker-compose -f docker-compose.lightsail.yml up -d nginx

echo "✅ SSL setup completed!"
EOF

chmod +x setup-ssl-lightsail.sh

# Create monitoring script
print_step "Creating monitoring script..."
cat > monitor-lightsail.sh << 'EOF'
#!/bin/bash

echo "🔍 PulseCal Lightsail Monitoring"
echo "==============================="

# System resources
echo "💾 Memory Usage:"
free -h

echo ""
echo "💿 Disk Usage:"
df -h /

echo ""
echo "🐳 Docker Status:"
docker-compose -f docker-compose.lightsail.yml ps

echo ""
echo "📊 Container Resources:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo ""
echo "🌐 Service Health:"
if curl -f -s http://localhost:8000/health/ > /dev/null; then
    echo "✅ Web service: Healthy"
else
    echo "❌ Web service: Unhealthy"
fi

echo ""
echo "📈 System Load:"
uptime
EOF

chmod +x monitor-lightsail.sh

# Set up automatic SSL renewal
print_step "Setting up automatic SSL renewal..."
echo "0 12 * * * /usr/bin/certbot renew --quiet --deploy-hook 'systemctl reload nginx'" | crontab -

# Set up monitoring cron
echo "*/5 * * * * /opt/pulsecal/monitor-lightsail.sh >> /opt/pulsecal/logs/monitor.log 2>&1" | crontab -

print_status ""
print_status "🎉 Lightsail Setup Completed!"
print_status "============================"
print_status "✅ System optimized for 512MB RAM"
print_status "✅ Docker and Docker Compose installed"
print_status "✅ Swap file created (1GB)"
print_status "✅ System service configured"
print_status "✅ SSL setup script ready"
print_status "✅ Monitoring tools installed"
print_status ""
print_status "📋 Next Steps:"
print_status "1. Upload your PulseCal application files"
print_status "2. Edit .env.lightsail with your settings"
print_status "3. Copy .env.lightsail to .env"
print_status "4. Run: ./deploy-lightsail.sh"
print_status "5. Set up SSL: ./setup-ssl-lightsail.sh"
print_status ""
print_status "🔧 Management Commands:"
print_status "- Deploy: ./deploy-lightsail.sh"
print_status "- Monitor: ./monitor-lightsail.sh"
print_status "- SSL Setup: ./setup-ssl-lightsail.sh"
print_status "- Service: sudo systemctl status pulsecal"
print_status ""
print_status "⚠️  Remember to reboot to apply all changes!"
print_status "sudo reboot"