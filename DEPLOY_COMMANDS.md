# 🚀 PulseCal Production Deployment Commands

## **Step 1: Connect to Lightsail Server**

Open Command Prompt or PowerShell and run:

```cmd
ssh -i "C:\Users\Lenovo\Desktop\LightsailDefaultKey-ap-south-1 (1).pem" ubuntu@13.200.76.254
```

## **Step 2: Upload Setup Script to Server**

From your local machine, upload the setup script:

```cmd
scp -i "C:\Users\Lenovo\Desktop\LightsailDefaultKey-ap-south-1 (1).pem" production-setup.sh ubuntu@13.200.76.254:~/
```

## **Step 3: Run Setup Script on Server**

Once connected to the server via SSH:

```bash
chmod +x production-setup.sh
./production-setup.sh
```

## **Alternative: Manual Commands on Server**

If you prefer to run commands manually, execute these on your Lightsail server:

### **1. Update System**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git nginx certbot python3-certbot-nginx
```

### **2. Install Docker**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
```

### **3. Install Docker Compose**
```bash
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### **4. Clone Your Repository**
```bash
cd /opt
sudo mkdir pulsecal
sudo chown ubuntu:ubuntu pulsecal
cd pulsecal
git clone https://github.com/YOUR_USERNAME/pulsecal.git .
```

### **5. Configure Environment**
```bash
cp .env.production.example .env
nano .env
```

**Update these critical settings in .env:**
```bash
SECRET_KEY=your-super-secret-key-here
ALLOWED_HOSTS=13.200.76.254,pulsecal.com,www.pulsecal.com
DB_PASSWORD=your-secure-password
DJANGO_SUPERUSER_PASSWORD=your-admin-password
```

### **6. Deploy Application**
```bash
chmod +x deploy.sh
./deploy.sh --production
```

## **Step 4: Access Your Application**

- **Main App**: http://13.200.76.254:8000
- **Admin Panel**: http://13.200.76.254:8000/admin

## **Step 5: Set Up Domain & SSL (Optional)**

### **Point Domain to Server**
Configure your DNS to point to: `13.200.76.254`

### **Set Up SSL Certificate**
```bash
sudo certbot --nginx -d pulsecal.com -d www.pulsecal.com
```

## **🔧 Useful Management Commands**

```bash
# View application logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Update application
git pull && ./deploy.sh --production

# Check service status
docker-compose ps

# Access database
docker-compose exec db psql -U pulsecal_user -d pulsecal_prod
```

## **🚨 Troubleshooting**

### **If deployment fails:**
```bash
docker-compose logs
docker-compose down
./deploy.sh --production
```

### **If services won't start:**
```bash
sudo systemctl restart docker
docker-compose down -v
./deploy.sh --production
```

### **Check server resources:**
```bash
df -h          # Disk space
free -h        # Memory usage
docker stats   # Container resources
```