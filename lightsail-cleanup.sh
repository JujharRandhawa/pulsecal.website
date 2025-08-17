#!/bin/bash

# PulseCal Lightsail Cleanup Script
# Use this to completely remove the Lightsail deployment

set -e

# Configuration
INSTANCE_NAME="pulsecal-production"
STATIC_IP_NAME="${INSTANCE_NAME}-static-ip"

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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_error "⚠️  WARNING: This will completely destroy your PulseCal deployment!"
print_error "⚠️  All data will be permanently lost!"
echo ""
read -p "Are you sure you want to continue? Type 'DELETE' to confirm: " confirmation

if [ "$confirmation" != "DELETE" ]; then
    print_status "Cleanup cancelled."
    exit 0
fi

print_step "Starting cleanup process..."

# Check if instance exists
if aws lightsail get-instance --instance-name "$INSTANCE_NAME" &>/dev/null; then
    print_step "Stopping instance..."
    aws lightsail stop-instance --instance-name "$INSTANCE_NAME" || true
    
    # Wait for instance to stop
    print_status "Waiting for instance to stop..."
    while true; do
        STATE=$(aws lightsail get-instance --instance-name "$INSTANCE_NAME" --query 'instance.state.name' --output text 2>/dev/null || echo "stopped")
        if [ "$STATE" = "stopped" ]; then
            break
        fi
        sleep 5
    done
    
    print_step "Deleting instance..."
    aws lightsail delete-instance --instance-name "$INSTANCE_NAME"
    print_status "Instance deleted"
else
    print_warning "Instance $INSTANCE_NAME not found"
fi

# Delete static IP
if aws lightsail get-static-ip --static-ip-name "$STATIC_IP_NAME" &>/dev/null; then
    print_step "Releasing static IP..."
    aws lightsail release-static-ip --static-ip-name "$STATIC_IP_NAME"
    print_status "Static IP released"
else
    print_warning "Static IP $STATIC_IP_NAME not found"
fi

# Delete snapshots
print_step "Checking for snapshots..."
SNAPSHOTS=$(aws lightsail get-instance-snapshots --query "instanceSnapshots[?contains(name, '$INSTANCE_NAME')].name" --output text 2>/dev/null || echo "")

if [ -n "$SNAPSHOTS" ]; then
    print_step "Deleting snapshots..."
    for snapshot in $SNAPSHOTS; do
        print_status "Deleting snapshot: $snapshot"
        aws lightsail delete-instance-snapshot --instance-snapshot-name "$snapshot" || true
    done
else
    print_status "No snapshots found"
fi

print_status "✅ Cleanup completed!"
print_status "All PulseCal Lightsail resources have been removed."
print_warning "Remember to:"
print_warning "1. Update your domain DNS settings"
print_warning "2. Cancel any monitoring services"
print_warning "3. Remove any external backups if no longer needed"