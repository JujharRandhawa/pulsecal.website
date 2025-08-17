@echo off
echo 🏥 PulseCal Production Deployment to AWS Lightsail
echo ================================================

echo.
echo Step 1: Connect to Lightsail server
echo ssh -i "C:\Users\Lenovo\Desktop\LightsailDefaultKey-ap-south-1 (1).pem" ubuntu@13.200.76.254

echo.
echo Step 2: Once connected, run these commands on the server:
echo.
echo # Update system
echo sudo apt update && sudo apt upgrade -y
echo.
echo # Install Docker
echo curl -fsSL https://get.docker.com -o get-docker.sh
echo sudo sh get-docker.sh
echo sudo usermod -aG docker ubuntu
echo.
echo # Install Docker Compose
echo sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
echo sudo chmod +x /usr/local/bin/docker-compose
echo.
echo # Clone your repository
echo git clone https://github.com/YOUR_USERNAME/pulsecal.git
echo cd pulsecal
echo.
echo # Create production environment file
echo cp .env.production.example .env
echo nano .env
echo.
echo # Deploy the application
echo chmod +x deploy.sh
echo ./deploy.sh --production
echo.
echo Step 3: Configure your domain to point to: 13.200.76.254
echo Step 4: Set up SSL certificate once domain is configured

pause