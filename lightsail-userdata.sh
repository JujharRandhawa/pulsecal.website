#!/bin/bash

# AWS Lightsail User Data Script for PulseCal
# This script runs on instance creation to set up the environment

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting PulseCal Lightsail setup..."

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    certbot \
    python3-certbot-nginx

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Start Docker service
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Create application directory
mkdir -p /opt/pulsecal
cd /opt/pulsecal

# Clone repository (you'll need to replace with your actual repo)
git clone https://github.com/your-username/pulsecal.git .

# Create production environment file
cat > .env << 'EOF'
# Production Environment for pulsecal.com
ENVIRONMENT=production
DEBUG=False

# Security - CHANGE THESE!
SECRET_KEY=your-super-secret-production-key-change-this
ALLOWED_HOSTS=pulsecal.com,www.pulsecal.com

# Database
DB_NAME=pulsecal_prod
DB_USER=pulsecal_user
DB_PASSWORD=secure-db-password-change-this

# CSRF and CORS
CSRF_TRUSTED_ORIGINS=https://pulsecal.com,https://www.pulsecal.com
CORS_ALLOWED_ORIGINS=https://pulsecal.com,https://www.pulsecal.com

# Email (configure with your SMTP)
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=noreply@pulsecal.com
EMAIL_HOST_PASSWORD=your-email-app-password
DEFAULT_FROM_EMAIL=PulseCal Healthcare <noreply@pulsecal.com>

# Google OAuth (configure with your credentials)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=https://pulsecal.com/accounts/google/login/callback/

# Google Maps API
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
GOOGLE_PLACES_API_KEY=your-google-places-api-key

# Superuser
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_EMAIL=admin@pulsecal.com
DJANGO_SUPERUSER_PASSWORD=change-this-admin-password
EOF

# Create SSL setup script
cat > setup-ssl.sh << 'EOF'
#!/bin/bash
echo "Setting up SSL for pulsecal.com..."

# Stop nginx if running
docker-compose down nginx 2>/dev/null || true

# Get SSL certificates
certbot certonly --standalone \
    -d pulsecal.com \
    -d www.pulsecal.com \
    --email admin@pulsecal.com \
    --agree-tos \
    --non-interactive

# Create SSL directory
mkdir -p ssl

# Copy certificates
cp /etc/letsencrypt/live/pulsecal.com/fullchain.pem ssl/cert.pem
cp /etc/letsencrypt/live/pulsecal.com/privkey.pem ssl/key.pem

# Set permissions
chown -R ubuntu:ubuntu ssl/
chmod 600 ssl/*.pem

# Start services with SSL
docker-compose -f docker-compose.prod.yml up -d

echo "SSL setup completed!"
echo "Your site should now be available at: https://pulsecal.com"
EOF

chmod +x setup-ssl.sh

# Create systemd service for auto-start
cat > /etc/systemd/system/pulsecal.service << 'EOF'
[Unit]
Description=PulseCal Healthcare Management System
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/pulsecal
ExecStart=/usr/local/bin/docker-compose -f docker-compose.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.yml down
TimeoutStartSec=0
User=ubuntu
Group=docker

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R ubuntu:ubuntu /opt/pulsecal
chmod +x /opt/pulsecal/*.sh

# Create data directories
mkdir -p /opt/pulsecal/data/{postgres,redis,media}
mkdir -p /opt/pulsecal/{logs,backups,ssl}
chown -R ubuntu:ubuntu /opt/pulsecal/data
chown -R ubuntu:ubuntu /opt/pulsecal/logs
chown -R ubuntu:ubuntu /opt/pulsecal/backups

# Initial deployment (without SSL first)
cd /opt/pulsecal
sudo -u ubuntu docker-compose build --no-cache
sudo -u ubuntu docker-compose up -d

# Enable service
systemctl enable pulsecal.service

# Set up log rotation
cat > /etc/logrotate.d/pulsecal << 'EOF'
/opt/pulsecal/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
    postrotate
        docker-compose -f /opt/pulsecal/docker-compose.yml restart web
    endscript
}
EOF

# Set up automatic SSL renewal
echo "0 12 * * * /usr/bin/certbot renew --quiet --deploy-hook 'systemctl reload nginx'" | crontab -

# Create monitoring script
cat > /opt/pulsecal/monitor.sh << 'EOF'
#!/bin/bash
# Simple monitoring script for PulseCal

cd /opt/pulsecal

# Check if services are running
if ! docker-compose ps | grep -q "Up"; then
    echo "Services down, restarting..."
    docker-compose up -d
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "Warning: Disk usage is ${DISK_USAGE}%"
    # Clean up old logs and backups
    find logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
    find backups/ -name "*.sql" -mtime +30 -delete 2>/dev/null || true
    docker system prune -f
fi

# Health check
if ! curl -f -s http://localhost:8000/health/ > /dev/null; then
    echo "Health check failed, restarting web service..."
    docker-compose restart web
fi
EOF

chmod +x /opt/pulsecal/monitor.sh

# Add monitoring to crontab
echo "*/5 * * * * /opt/pulsecal/monitor.sh >> /opt/pulsecal/logs/monitor.log 2>&1" | sudo -u ubuntu crontab -

# Create backup script
cat > /opt/pulsecal/backup.sh << 'EOF'
#!/bin/bash
cd /opt/pulsecal

DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="backups"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database
docker-compose exec -T db pg_dump -U pulsecal_user pulsecal_prod | gzip > "$BACKUP_DIR/db_backup_$DATE.sql.gz"

# Backup media files
tar -czf "$BACKUP_DIR/media_backup_$DATE.tar.gz" data/media/

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "*.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /opt/pulsecal/backup.sh

# Schedule daily backups
echo "0 2 * * * /opt/pulsecal/backup.sh >> /opt/pulsecal/logs/backup.log 2>&1" | sudo -u ubuntu crontab -

echo "PulseCal Lightsail setup completed!"
echo "Next steps:"
echo "1. Point your domain to this server's IP"
echo "2. Run: sudo /opt/pulsecal/setup-ssl.sh"
echo "3. Configure your .env file with actual credentials"