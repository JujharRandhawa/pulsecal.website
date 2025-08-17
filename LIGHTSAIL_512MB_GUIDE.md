# 🏥 PulseCal Deployment on AWS Lightsail (512MB)

Complete guide for deploying PulseCal on a 512MB RAM Lightsail instance.

## 📊 Instance Specifications
- **RAM**: 512 MB
- **vCPUs**: 2
- **Storage**: 20 GB SSD
- **OS**: Ubuntu 20.04 LTS
- **Cost**: ~$3.50/month

## 🚀 Quick Deployment

### Step 1: Upload Files to Lightsail
```bash
# From your local machine, upload files to Lightsail
scp -i ~/.ssh/LightsailDefaultKey-us-east-1.pem -r . ubuntu@YOUR_IP:/opt/pulsecal/
```

### Step 2: Run Setup on Lightsail
```bash
# SSH to your Lightsail instance
ssh -i ~/.ssh/LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_IP

# Run the setup script
cd /opt/pulsecal
chmod +x lightsail-setup.sh
./lightsail-setup.sh
```

### Step 3: Configure Environment
```bash
# Copy and edit environment file
cp .env.lightsail .env
nano .env

# Update these critical settings:
SECRET_KEY=your-unique-secret-key
DB_PASSWORD=your-secure-password
ALLOWED_HOSTS=your-domain.com,www.your-domain.com
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
EMAIL_HOST_PASSWORD=your-email-password
```

### Step 4: Deploy Application
```bash
# Deploy PulseCal
./deploy-lightsail.sh
```

### Step 5: Set Up SSL (Optional)
```bash
# Edit SSL script with your domain
nano setup-ssl-lightsail.sh
# Update your-domain.com to your actual domain

# Run SSL setup
./setup-ssl-lightsail.sh
```

## 🔧 Memory Optimizations

### System Optimizations:
- **1GB Swap File** - Virtual memory for low RAM
- **Kernel Parameters** - Optimized for low memory
- **Log Rotation** - Prevents disk space issues
- **Docker Limits** - Resource constraints per service

### Application Optimizations:
- **2 Gunicorn Workers** (instead of 4)
- **Sync Worker Class** (lower memory than gevent)
- **Reduced Buffer Sizes** - Smaller memory footprint
- **PostgreSQL Tuning** - Optimized for 512MB
- **Redis Memory Limit** - 48MB max with LRU eviction

### Service Memory Allocation:
```
Web Service:    200MB (40%)
Database:       200MB (40%)
Redis:          64MB  (12%)
Nginx:          48MB  (8%)
Total:          512MB (100%)
```

## 📊 Performance Expectations

### Expected Performance:
- **Concurrent Users**: 10-20
- **Response Time**: 200-500ms
- **Database**: Small to medium datasets
- **File Uploads**: Up to 5MB
- **Uptime**: 99%+ with monitoring

### Limitations:
- **Heavy Traffic**: May need scaling
- **Large Files**: Limited by memory
- **Complex Queries**: May be slower
- **Background Tasks**: Limited Celery workers

## 🔍 Monitoring & Maintenance

### Monitor System Resources:
```bash
# Check system status
./monitor-lightsail.sh

# View service logs
docker-compose -f docker-compose.lightsail.yml logs -f

# Check memory usage
free -h

# Check disk usage
df -h
```

### Common Maintenance Tasks:
```bash
# Restart services
sudo systemctl restart pulsecal

# Clean up Docker
docker system prune -f

# View system logs
sudo journalctl -u pulsecal -f

# Update application
git pull && ./deploy-lightsail.sh
```

## 🛠️ Troubleshooting

### Memory Issues:
```bash
# Check memory usage
free -h
docker stats

# Clear caches
sync && echo 3 > /proc/sys/vm/drop_caches

# Restart services to free memory
sudo systemctl restart pulsecal
```

### Service Issues:
```bash
# Check service status
sudo systemctl status pulsecal

# View Docker logs
docker-compose -f docker-compose.lightsail.yml logs

# Restart specific service
docker-compose -f docker-compose.lightsail.yml restart web
```

### Database Issues:
```bash
# Check database connection
docker-compose -f docker-compose.lightsail.yml exec db pg_isready

# Access database
docker-compose -f docker-compose.lightsail.yml exec db psql -U pulsecal_user -d pulsecal_db

# Reset database (CAUTION: Deletes all data)
docker-compose -f docker-compose.lightsail.yml down
docker volume rm pulsecal_postgres_data
./deploy-lightsail.sh
```

## 📈 Scaling Options

### Vertical Scaling:
1. **Upgrade Instance** - Move to 1GB or 2GB plan
2. **Snapshot First** - Create backup before upgrade
3. **Update Configuration** - Increase worker counts

### Horizontal Scaling:
1. **Load Balancer** - AWS Application Load Balancer
2. **Database Separation** - Dedicated RDS instance
3. **CDN** - CloudFront for static files

## 💰 Cost Optimization

### Current Costs:
- **Lightsail Instance**: $3.50/month
- **Data Transfer**: 1TB included
- **Static IP**: Free
- **Total**: ~$3.50/month

### Cost Reduction Tips:
- **Regular Cleanup** - Remove old logs and backups
- **Optimize Images** - Compress media files
- **Monitor Usage** - Track data transfer
- **Scheduled Tasks** - Run maintenance during low usage

## 🔐 Security Considerations

### Implemented Security:
- **Firewall Rules** - Only necessary ports open
- **SSL/TLS** - HTTPS encryption
- **Regular Updates** - Automated security patches
- **Resource Limits** - Prevent resource exhaustion
- **Log Monitoring** - Track access and errors

### Additional Security:
- **Fail2Ban** - Brute force protection
- **VPC** - Network isolation
- **Backup Strategy** - Regular data backups
- **Monitoring** - Real-time alerts

## 📋 Maintenance Schedule

### Daily:
- **Automated Backups** - Database and media files
- **Log Rotation** - Prevent disk space issues
- **Health Checks** - Service monitoring

### Weekly:
- **System Updates** - Security patches
- **Performance Review** - Resource usage analysis
- **Backup Verification** - Test restore procedures

### Monthly:
- **Security Audit** - Review access logs
- **Performance Optimization** - Database maintenance
- **Capacity Planning** - Growth analysis

## 🎯 Success Metrics

### Key Performance Indicators:
- **Uptime**: >99%
- **Response Time**: <500ms
- **Memory Usage**: <90%
- **Disk Usage**: <80%
- **Error Rate**: <1%

### Monitoring Alerts:
- **High Memory Usage** - >90%
- **High Disk Usage** - >80%
- **Service Down** - Any service failure
- **SSL Expiry** - 30 days before expiration

## 🚨 Emergency Procedures

### Service Recovery:
```bash
# Quick restart
sudo systemctl restart pulsecal

# Full reset
docker-compose -f docker-compose.lightsail.yml down
docker system prune -f
./deploy-lightsail.sh
```

### Data Recovery:
```bash
# Restore from backup
# (Backup files are in /opt/pulsecal/backups/)
```

### Instance Recovery:
1. **Create Snapshot** - Before any major changes
2. **Launch New Instance** - From snapshot if needed
3. **Update DNS** - Point domain to new IP
4. **Restore Data** - From backups if necessary

## ✅ Deployment Checklist

- [ ] Lightsail instance created (512MB, Ubuntu)
- [ ] Files uploaded to /opt/pulsecal/
- [ ] Setup script executed
- [ ] Environment file configured
- [ ] Application deployed successfully
- [ ] SSL certificates installed (optional)
- [ ] Domain DNS configured
- [ ] Monitoring set up
- [ ] Backups configured
- [ ] Admin password changed

## 🎉 Success!

Your PulseCal Healthcare Management System is now running on AWS Lightsail with:

- ✅ **Optimized for 512MB RAM**
- ✅ **Production-ready configuration**
- ✅ **Automated monitoring and backups**
- ✅ **SSL/HTTPS support**
- ✅ **Cost-effective hosting (~$3.50/month)**

**Access your application at**: `http://YOUR_LIGHTSAIL_IP:8000`

**Admin panel**: `http://YOUR_LIGHTSAIL_IP:8000/admin`

**Default admin**: `admin` / `admin123` (change immediately!)

Your healthcare management system is ready to serve patients and healthcare providers! 🏥✨