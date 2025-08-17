# 🚀 PulseCal AWS Lightsail Deployment Guide

Complete guide for deploying PulseCal Healthcare Management System on AWS Lightsail.

## 📋 Prerequisites

### Local Requirements
- AWS CLI installed and configured
- Git repository with your PulseCal code
- Domain name (pulsecal.com) ready to point to server

### AWS Account Setup
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
```

## 🚀 Quick Deployment

### 1. Deploy to Lightsail
```bash
# Make deployment script executable
chmod +x lightsail-deploy.sh

# Deploy to AWS Lightsail
./lightsail-deploy.sh
```

### 2. Point Domain to Server
- Go to your domain registrar
- Point `pulsecal.com` and `www.pulsecal.com` to the static IP provided
- Wait for DNS propagation (5-30 minutes)

### 3. Configure SSL
```bash
# SSH to your server
ssh -i ~/.ssh/LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_STATIC_IP

# Set up SSL certificates
sudo /opt/pulsecal/setup-ssl.sh
```

### 4. Configure Environment
```bash
# Edit production environment
sudo nano /opt/pulsecal/.env

# Update these critical settings:
SECRET_KEY=your-unique-secret-key
DB_PASSWORD=your-secure-database-password
GOOGLE_CLIENT_ID=your-google-oauth-client-id
GOOGLE_CLIENT_SECRET=your-google-oauth-secret
EMAIL_HOST_PASSWORD=your-email-app-password
```

### 5. Restart Services
```bash
cd /opt/pulsecal
sudo docker-compose restart
```

## 🎯 What Gets Deployed

### Server Specifications
- **Instance**: Ubuntu 20.04 LTS
- **Size**: 2 vCPU, 4GB RAM, 60GB SSD
- **Region**: US East (N. Virginia)
- **Cost**: ~$20/month

### Installed Components
- Docker & Docker Compose
- Nginx with SSL/TLS
- PostgreSQL database
- Redis cache
- Celery task queue
- SSL certificates (Let's Encrypt)
- Automated backups
- Health monitoring

### Security Features
- Firewall configured (ports 22, 80, 443)
- SSL/TLS encryption
- Automated certificate renewal
- Non-root container execution
- Database password protection

## 🔧 Post-Deployment Configuration

### 1. Google OAuth Setup
```bash
# Go to Google Cloud Console
# Create OAuth 2.0 credentials
# Add authorized redirect URIs:
https://pulsecal.com/accounts/google/login/callback/
https://www.pulsecal.com/accounts/google/login/callback/
```

### 2. Email Configuration
```bash
# For Gmail SMTP:
EMAIL_HOST=smtp.gmail.com
EMAIL_HOST_USER=noreply@pulsecal.com
EMAIL_HOST_PASSWORD=your-app-password  # Generate in Gmail settings
```

### 3. Google Maps API
```bash
# Enable these APIs in Google Cloud Console:
# - Maps JavaScript API
# - Places API
# - Geocoding API

GOOGLE_MAPS_API_KEY=your-maps-api-key
GOOGLE_PLACES_API_KEY=your-places-api-key
```

## 📊 Monitoring & Maintenance

### Health Monitoring
```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs -f

# Monitor system resources
htop
df -h
```

### Automated Features
- **Health Checks**: Every 5 minutes
- **Backups**: Daily at 2 AM
- **SSL Renewal**: Automatic every 90 days
- **Log Rotation**: Daily with 30-day retention

### Manual Backup
```bash
cd /opt/pulsecal
./backup.sh
```

### Manual SSL Renewal
```bash
sudo certbot renew
sudo systemctl reload nginx
```

## 🛠️ Troubleshooting

### Services Won't Start
```bash
# Check logs
docker-compose logs

# Restart services
docker-compose down
docker-compose up -d

# Check disk space
df -h
```

### SSL Issues
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates manually
sudo certbot renew --force-renewal

# Restart nginx
docker-compose restart nginx
```

### Database Issues
```bash
# Access database
docker-compose exec db psql -U pulsecal_user -d pulsecal_prod

# Reset database (CAUTION: This deletes all data)
docker-compose down
docker volume rm pulsecal_postgres_data
docker-compose up -d
```

### Performance Issues
```bash
# Check resource usage
docker stats

# Clean up Docker
docker system prune -f

# Restart services
docker-compose restart
```

## 📈 Scaling Options

### Vertical Scaling (Upgrade Instance)
```bash
# Stop services
docker-compose down

# In AWS Console:
# 1. Create snapshot of instance
# 2. Upgrade to larger bundle
# 3. Restart services
```

### Horizontal Scaling (Load Balancer)
- Use AWS Application Load Balancer
- Deploy multiple Lightsail instances
- Configure database replication

## 💰 Cost Optimization

### Current Costs (Monthly)
- Lightsail Instance: ~$20
- Static IP: Free (with instance)
- Data Transfer: 3TB included
- **Total**: ~$20/month

### Cost Reduction Tips
- Use smaller instance for development
- Enable log rotation
- Regular cleanup of old backups
- Monitor data transfer usage

## 🔐 Security Best Practices

### Implemented Security
- ✅ SSL/TLS encryption
- ✅ Firewall configuration
- ✅ Non-root containers
- ✅ Automated security updates
- ✅ Strong password policies

### Additional Recommendations
- Enable AWS CloudTrail
- Set up AWS Config
- Use AWS Secrets Manager
- Enable VPC Flow Logs
- Regular security audits

## 📞 Support & Maintenance

### Log Locations
- Application: `/opt/pulsecal/logs/`
- System: `/var/log/`
- Docker: `docker-compose logs`

### Backup Locations
- Local: `/opt/pulsecal/backups/`
- Retention: 7 days local

### Key Commands
```bash
# Service management
sudo systemctl status pulsecal
sudo systemctl restart pulsecal

# Application management
cd /opt/pulsecal
docker-compose ps
docker-compose logs -f
docker-compose restart

# System monitoring
htop
df -h
free -h
```

## 🎉 Success Indicators

When deployment is successful, you should see:
- ✅ Application accessible at https://pulsecal.com
- ✅ SSL certificate valid and auto-renewing
- ✅ All Docker services running
- ✅ Database migrations completed
- ✅ Admin panel accessible
- ✅ Health checks passing

---

## 🚨 Emergency Procedures

### Complete System Recovery
```bash
# 1. Create new Lightsail instance
./lightsail-deploy.sh

# 2. Restore from backup
scp backups/latest_backup.sql.gz ubuntu@NEW_IP:/opt/pulsecal/
ssh ubuntu@NEW_IP
cd /opt/pulsecal
gunzip -c latest_backup.sql.gz | docker-compose exec -T db psql -U pulsecal_user -d pulsecal_prod

# 3. Update DNS to new IP
```

### Rollback Deployment
```bash
# Restore from backup
cd /opt/pulsecal
docker-compose down
# Restore database from backup
# Restart services
docker-compose up -d
```

Your PulseCal Healthcare Management System is now production-ready on AWS Lightsail! 🏥✨