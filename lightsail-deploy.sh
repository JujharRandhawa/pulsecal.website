#!/bin/bash

# PulseCal AWS Lightsail Deployment Script
# Automated deployment to AWS Lightsail for pulsecal.com

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

# Configuration
INSTANCE_NAME="pulsecal-production"
DOMAIN="pulsecal.com"
REGION="us-east-1"
BUNDLE_ID="medium_2_0"  # 2 vCPU, 4GB RAM, 60GB SSD

print_status "🏥 PulseCal AWS Lightsail Deployment"
print_status "===================================="

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Check if logged in to AWS
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "Not logged in to AWS. Run: aws configure"
    exit 1
fi

print_step "Creating Lightsail instance..."

# Create instance
aws lightsail create-instances \
    --instance-names "$INSTANCE_NAME" \
    --availability-zone "${REGION}a" \
    --blueprint-id "ubuntu_20_04" \
    --bundle-id "$BUNDLE_ID" \
    --user-data file://lightsail-userdata.sh \
    --tags key=Project,value=PulseCal key=Environment,value=Production

print_status "Instance creation initiated. Waiting for instance to be running..."

# Wait for instance to be running
while true; do
    STATE=$(aws lightsail get-instance --instance-name "$INSTANCE_NAME" --query 'instance.state.name' --output text)
    if [ "$STATE" = "running" ]; then
        break
    fi
    print_status "Instance state: $STATE. Waiting..."
    sleep 10
done

print_status "Instance is running!"

# Get instance IP
INSTANCE_IP=$(aws lightsail get-instance --instance-name "$INSTANCE_NAME" --query 'instance.publicIpAddress' --output text)
print_status "Instance IP: $INSTANCE_IP"

# Create static IP
print_step "Creating static IP..."
aws lightsail allocate-static-ip --static-ip-name "${INSTANCE_NAME}-static-ip"

# Attach static IP
STATIC_IP=$(aws lightsail get-static-ip --static-ip-name "${INSTANCE_NAME}-static-ip" --query 'staticIp.ipAddress' --output text)
aws lightsail attach-static-ip --static-ip-name "${INSTANCE_NAME}-static-ip" --instance-name "$INSTANCE_NAME"

print_status "Static IP attached: $STATIC_IP"

# Open firewall ports
print_step "Configuring firewall..."
aws lightsail put-instance-public-ports \
    --instance-name "$INSTANCE_NAME" \
    --port-infos fromPort=22,toPort=22,protocol=TCP \
                 fromPort=80,toPort=80,protocol=TCP \
                 fromPort=443,toPort=443,protocol=TCP

print_status "Firewall configured for HTTP, HTTPS, and SSH"

# Wait for user data script to complete
print_step "Waiting for server setup to complete (this may take 5-10 minutes)..."
sleep 300

print_status "🎉 Lightsail deployment completed!"
print_status "=================================="
print_status "Instance Name: $INSTANCE_NAME"
print_status "Static IP: $STATIC_IP"
print_status "SSH Command: ssh -i ~/.ssh/LightsailDefaultKey-${REGION}.pem ubuntu@${STATIC_IP}"
print_status ""
print_status "Next steps:"
print_status "1. Point your domain $DOMAIN to IP: $STATIC_IP"
print_status "2. SSH to server and run: sudo /opt/pulsecal/setup-ssl.sh"
print_status "3. Access your application at: https://$DOMAIN"