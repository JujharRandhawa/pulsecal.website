# 🚀 PulseCal Production Deployment Guide

Complete guide for deploying PulseCal Healthcare Management System in production.

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ / CentOS 8+ / RHEL 8+
- **RAM**: Minimum 4GB, Recommended 8GB+
- **Storage**: Minimum 20GB, Recommended 50GB+
- **CPU**: 2+ cores recommended

### Required Software
- Docker 24.0+
- Docker Compose 2.0+
- Git
- curl
- SSL certificates (for HTTPS)

## 🔧 Quick Deployment

### 1. Clone Repository
```bash
git clone https://github.com/your-org/pulsecal.git
cd pulsecal
```

### 2. Configure Environment
```bash
# Copy production environment template
cp .env.production.example .env

# Edit configuration
nano .env
```

### 3. Deploy
```bash
# Make scripts executable
chmod +x deploy.sh backup.sh restore.sh

# Deploy application
./deploy.sh --production
```

## ⚙️ Environment Configuration

### Required Variables
```bash
# Security
SECRET_KEY=your-super-secret-key-here
ALLOWED_HOSTS=pulsecal.com,www.pulsecal.com

# Database
DB_PASSWORD=your-secure-database-password

# Email
EMAIL_HOST=smtp.gmail.com
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password

# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=https://pulsecal.com/accounts/google/login/callback/

# Security Headers
CSRF_TRUSTED_ORIGINS=https://pulsecal.com,https://www.pulsecal.com
CORS_ALLOWED_ORIGINS=https://pulsecal.com,https://www.pulsecal.com
```

### Optional Variables
```bash
# Google Maps
GOOGLE_MAPS_API_KEY=your-maps-api-key
GOOGLE_PLACES_API_KEY=your-places-api-key

# Monitoring
SENTRY_DSN=your-sentry-dsn

# Backup
AWS_S3_BUCKET=your-backup-bucket
BACKUP_WEBHOOK_URL=your-slack-webhook
```

## 🔐 SSL/TLS Setup

### Using Let's Encrypt (Recommended)
```bash
# Install certbot
sudo apt install certbot

# Generate certificates
sudo certbot certonly --standalone -d pulsecal.com -d www.pulsecal.com

# Create SSL directory
mkdir -p ssl

# Copy certificates
sudo cp /etc/letsencrypt/live/pulsecal.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/pulsecal.com/privkey.pem ssl/key.pem
sudo chown $USER:$USER ssl/*
```

### Using Custom Certificates
```bash
# Create SSL directory
mkdir -p ssl

# Copy your certificates
cp your-certificate.pem ssl/cert.pem
cp your-private-key.pem ssl/key.pem
```

## 🐳 Docker Deployment Options

### Standard Deployment
```bash
# Use default docker-compose.yml
./deploy.sh
```

### Production Deployment with Nginx
```bash
# Use production compose file
docker-compose -f docker-compose.prod.yml up -d
```

### Development Deployment
```bash
# Set development environment
export ENVIRONMENT=development
./deploy.sh
```

## 📊 Monitoring & Health Checks

### Health Check Endpoint
```bash
# Check application health
curl http://localhost:8000/health/

# Detailed health check
python health_check.py --json
```

### Service Status
```bash
# Check all services
docker-compose ps

# View logs
docker-compose logs -f

# Monitor resources
docker stats
```

### Log Locations
- Application logs: `logs/django.log`
- Nginx logs: `/var/log/nginx/`
- PostgreSQL logs: Docker container logs
- Redis logs: Docker container logs

## 💾 Backup & Restore

### Automated Backups
```bash
# Create backup
./backup.sh

# Schedule daily backups (crontab)
0 2 * * * /path/to/pulsecal/backup.sh
```

### Restore from Backup
```bash
# List available backups
./restore.sh

# Restore specific backup
./restore.sh 20241201_143022
```

### Backup Components
- PostgreSQL database
- Media files (uploads)
- Static files
- Configuration files

## 🔄 Updates & Maintenance

### Application Updates
```bash
# Pull latest changes
git pull origin main

# Redeploy
./deploy.sh --production
```

### Database Migrations
```bash
# Run migrations
docker-compose exec web python manage.py migrate

# Create superuser
docker-compose exec web python manage.py createsuperuser
```

### Static Files
```bash
# Collect static files
docker-compose exec web python manage.py collectstatic --noinput
```

## 🛡️ Security Considerations

### Firewall Configuration
```bash
# Allow HTTP/HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Allow SSH (if needed)
sudo ufw allow 22

# Enable firewall
sudo ufw enable
```

### Database Security
- Use strong passwords
- Enable SSL connections
- Regular security updates
- Backup encryption

### Application Security
- Keep Django updated
- Regular dependency updates
- Monitor security advisories
- Use HTTPS only in production

## 📈 Performance Optimization

### Database Optimization
```sql
-- Create indexes for better performance
CREATE INDEX CONCURRENTLY idx_appointments_date ON appointments_appointment(appointment_date);
CREATE INDEX CONCURRENTLY idx_appointments_patient ON appointments_appointment(patient_id);
CREATE INDEX CONCURRENTLY idx_appointments_doctor ON appointments_appointment(doctor_id);
```

### Redis Configuration
- Configure memory limits
- Enable persistence
- Monitor memory usage

### Nginx Optimization
- Enable gzip compression
- Configure caching headers
- Optimize buffer sizes

## 🚨 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check logs
docker-compose logs

# Check disk space
df -h

# Check memory
free -h
```

#### Database Connection Issues
```bash
# Check database status
docker-compose exec db pg_isready

# Reset database
docker-compose down -v
./deploy.sh
```

#### SSL Certificate Issues
```bash
# Verify certificates
openssl x509 -in ssl/cert.pem -text -noout

# Check certificate expiry
openssl x509 -in ssl/cert.pem -noout -dates
```

### Performance Issues
```bash
# Monitor resource usage
docker stats

# Check slow queries
docker-compose exec db psql -U pulsecal_user -d pulsecal_db -c "SELECT * FROM pg_stat_activity;"

# Clear cache
docker-compose exec web python manage.py shell -c "from django.core.cache import cache; cache.clear()"
```

## 📞 Support & Maintenance

### Regular Maintenance Tasks
- [ ] Weekly backups verification
- [ ] Monthly security updates
- [ ] Quarterly performance review
- [ ] SSL certificate renewal (every 90 days for Let's Encrypt)

### Monitoring Checklist
- [ ] Application health checks
- [ ] Database performance
- [ ] Disk space usage
- [ ] Memory usage
- [ ] SSL certificate expiry
- [ ] Backup integrity

### Emergency Procedures
1. **Service Outage**: Check logs, restart services
2. **Database Issues**: Restore from latest backup
3. **Security Breach**: Isolate system, review logs, update credentials
4. **Data Loss**: Restore from backup, verify integrity

## 📚 Additional Resources

- [Django Deployment Checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Nginx Security Headers](https://securityheaders.com/)

---

## 🎯 Quick Commands Reference

```bash
# Deployment
./deploy.sh --production

# Backup
./backup.sh

# Restore
./restore.sh YYYYMMDD_HHMMSS

# Health Check
python health_check.py

# View Logs
docker-compose logs -f [service]

# Service Management
docker-compose up -d
docker-compose down
docker-compose restart [service]

# Database Access
docker-compose exec db psql -U pulsecal_user -d pulsecal_db

# Django Management
docker-compose exec web python manage.py [command]
```

---

*For additional support, please refer to the project documentation or contact the development team.*