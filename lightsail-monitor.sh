#!/bin/bash

# PulseCal Lightsail Monitoring Script
# Run this locally to monitor your Lightsail deployment

set -e

# Configuration
INSTANCE_NAME="pulsecal-production"
DOMAIN="pulsecal.com"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

print_header "PulseCal Lightsail Monitoring Dashboard"

# Get instance information
print_status "Fetching instance information..."

INSTANCE_INFO=$(aws lightsail get-instance --instance-name "$INSTANCE_NAME" 2>/dev/null || echo "")

if [ -z "$INSTANCE_INFO" ]; then
    print_error "Instance '$INSTANCE_NAME' not found!"
    exit 1
fi

# Parse instance details
INSTANCE_STATE=$(echo "$INSTANCE_INFO" | jq -r '.instance.state.name')
INSTANCE_IP=$(echo "$INSTANCE_INFO" | jq -r '.instance.publicIpAddress')
INSTANCE_PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.instance.privateIpAddress')
INSTANCE_BLUEPRINT=$(echo "$INSTANCE_INFO" | jq -r '.instance.blueprintName')
INSTANCE_BUNDLE=$(echo "$INSTANCE_INFO" | jq -r '.instance.bundleId')

print_header "Instance Status"
echo "Name: $INSTANCE_NAME"
echo "State: $INSTANCE_STATE"
echo "Public IP: $INSTANCE_IP"
echo "Private IP: $INSTANCE_PRIVATE_IP"
echo "Blueprint: $INSTANCE_BLUEPRINT"
echo "Bundle: $INSTANCE_BUNDLE"

# Check static IP
print_header "Static IP Status"
STATIC_IP_INFO=$(aws lightsail get-static-ip --static-ip-name "${INSTANCE_NAME}-static-ip" 2>/dev/null || echo "")

if [ -n "$STATIC_IP_INFO" ]; then
    STATIC_IP=$(echo "$STATIC_IP_INFO" | jq -r '.staticIp.ipAddress')
    STATIC_IP_ATTACHED=$(echo "$STATIC_IP_INFO" | jq -r '.staticIp.attachedTo')
    echo "Static IP: $STATIC_IP"
    echo "Attached to: $STATIC_IP_ATTACHED"
else
    print_warning "No static IP found"
fi

# Check domain resolution
print_header "Domain Resolution"
if command -v dig &> /dev/null; then
    DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)
    if [ "$DOMAIN_IP" = "$STATIC_IP" ]; then
        print_status "✅ Domain $DOMAIN resolves to correct IP: $DOMAIN_IP"
    else
        print_warning "⚠️ Domain $DOMAIN resolves to: $DOMAIN_IP (expected: $STATIC_IP)"
    fi
    
    WWW_DOMAIN_IP=$(dig +short "www.$DOMAIN" | tail -n1)
    if [ "$WWW_DOMAIN_IP" = "$STATIC_IP" ]; then
        print_status "✅ www.$DOMAIN resolves to correct IP: $WWW_DOMAIN_IP"
    else
        print_warning "⚠️ www.$DOMAIN resolves to: $WWW_DOMAIN_IP (expected: $STATIC_IP)"
    fi
else
    print_warning "dig command not available, skipping DNS check"
fi

# Check HTTP/HTTPS connectivity
print_header "Connectivity Tests"

# HTTP check
if curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN" | grep -q "200\|301\|302"; then
    print_status "✅ HTTP connection to $DOMAIN successful"
else
    print_error "❌ HTTP connection to $DOMAIN failed"
fi

# HTTPS check
if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" | grep -q "200"; then
    print_status "✅ HTTPS connection to $DOMAIN successful"
else
    print_error "❌ HTTPS connection to $DOMAIN failed"
fi

# Health check
if curl -s -f "https://$DOMAIN/health/" > /dev/null 2>&1; then
    print_status "✅ Application health check passed"
else
    print_warning "⚠️ Application health check failed"
fi

# SSL Certificate check
print_header "SSL Certificate Status"
if command -v openssl &> /dev/null; then
    SSL_INFO=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [ -n "$SSL_INFO" ]; then
        echo "$SSL_INFO"
        
        # Check expiration
        EXPIRY_DATE=$(echo "$SSL_INFO" | grep "notAfter" | cut -d= -f2)
        EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo "0")
        CURRENT_TIMESTAMP=$(date +%s)
        DAYS_UNTIL_EXPIRY=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))
        
        if [ "$DAYS_UNTIL_EXPIRY" -gt 30 ]; then
            print_status "✅ SSL certificate expires in $DAYS_UNTIL_EXPIRY days"
        elif [ "$DAYS_UNTIL_EXPIRY" -gt 7 ]; then
            print_warning "⚠️ SSL certificate expires in $DAYS_UNTIL_EXPIRY days"
        else
            print_error "❌ SSL certificate expires in $DAYS_UNTIL_EXPIRY days - URGENT RENEWAL NEEDED"
        fi
    else
        print_error "❌ Could not retrieve SSL certificate information"
    fi
else
    print_warning "openssl command not available, skipping SSL check"
fi

# Instance metrics
print_header "Instance Metrics (Last 24 Hours)"

# CPU utilization
CPU_METRICS=$(aws lightsail get-instance-metric-data \
    --instance-name "$INSTANCE_NAME" \
    --metric-name "CPUUtilization" \
    --period 3600 \
    --start-time "$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    --statistics "Average" \
    --unit "Percent" 2>/dev/null || echo "")

if [ -n "$CPU_METRICS" ]; then
    AVG_CPU=$(echo "$CPU_METRICS" | jq -r '.metricData[] | .average' | awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "N/A"}')
    echo "Average CPU Usage: ${AVG_CPU}%"
else
    print_warning "Could not retrieve CPU metrics"
fi

# Network metrics
NETWORK_IN=$(aws lightsail get-instance-metric-data \
    --instance-name "$INSTANCE_NAME" \
    --metric-name "NetworkIn" \
    --period 3600 \
    --start-time "$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    --statistics "Sum" \
    --unit "Bytes" 2>/dev/null || echo "")

if [ -n "$NETWORK_IN" ]; then
    TOTAL_NETWORK_IN=$(echo "$NETWORK_IN" | jq -r '.metricData[] | .sum' | awk '{sum+=$1} END {printf "%.2f", sum/1024/1024}')
    echo "Network In (24h): ${TOTAL_NETWORK_IN} MB"
fi

# Firewall rules
print_header "Firewall Configuration"
FIREWALL_RULES=$(aws lightsail get-instance-port-states --instance-name "$INSTANCE_NAME" 2>/dev/null || echo "")

if [ -n "$FIREWALL_RULES" ]; then
    echo "$FIREWALL_RULES" | jq -r '.portStates[] | "\(.fromPort)-\(.toPort)/\(.protocol): \(.state)"'
else
    print_warning "Could not retrieve firewall rules"
fi

# Snapshots
print_header "Instance Snapshots"
SNAPSHOTS=$(aws lightsail get-instance-snapshots --query "instanceSnapshots[?contains(name, '$INSTANCE_NAME')]" 2>/dev/null || echo "[]")

SNAPSHOT_COUNT=$(echo "$SNAPSHOTS" | jq length)
echo "Total snapshots: $SNAPSHOT_COUNT"

if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
    echo "Latest snapshots:"
    echo "$SNAPSHOTS" | jq -r 'sort_by(.createdAt) | reverse | .[0:3][] | "\(.name) - \(.createdAt) - \(.state)"'
fi

# Cost estimation
print_header "Cost Information"
echo "Estimated monthly cost: ~$20 USD (based on $INSTANCE_BUNDLE bundle)"
echo "Data transfer included: 3 TB/month"

# Quick actions
print_header "Quick Actions"
echo "SSH to instance: ssh -i ~/.ssh/LightsailDefaultKey-us-east-1.pem ubuntu@$STATIC_IP"
echo "View application logs: ssh ubuntu@$STATIC_IP 'cd /opt/pulsecal && docker-compose logs -f'"
echo "Restart services: ssh ubuntu@$STATIC_IP 'cd /opt/pulsecal && docker-compose restart'"
echo "Create snapshot: aws lightsail create-instance-snapshot --instance-name $INSTANCE_NAME --instance-snapshot-name ${INSTANCE_NAME}-$(date +%Y%m%d-%H%M%S)"

print_header "Monitoring Complete"
print_status "For real-time monitoring, consider setting up CloudWatch or a monitoring service."
print_status "Run this script regularly or set up automated monitoring alerts."