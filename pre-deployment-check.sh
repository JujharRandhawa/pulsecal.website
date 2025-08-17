#!/bin/bash

# PulseCal Pre-Deployment Comprehensive Check
# Final validation before production deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

check_result() {
    if [ $1 -eq 0 ]; then
        print_success "✅ $2"
        ((CHECKS_PASSED++))
    else
        print_error "❌ $2"
        ((CHECKS_FAILED++))
    fi
}

warning_result() {
    print_warning "⚠️  $1"
    ((WARNINGS++))
}

print_status "🏥 PulseCal Pre-Deployment Check"
print_status "==============================="

# Make scripts executable
chmod +x *.sh 2>/dev/null || true

# Step 1: Fix common issues first
print_step "Running automatic fixes..."
./fix-common-issues.sh > /dev/null 2>&1
check_result $? "Common issues fixed"

# Step 2: Environment validation
print_step "Validating environment..."
if [ ! -f .env ]; then
    print_error "No .env file found"
    exit 1
fi

source .env
required_vars=("SECRET_KEY" "DB_PASSWORD" "ALLOWED_HOSTS")
env_errors=0
for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        print_error "Missing: $var"
        env_errors=1
    fi
done
check_result $env_errors "Environment variables"

# Step 3: Docker system check
print_step "Checking Docker system..."
docker --version > /dev/null 2>&1
check_result $? "Docker installation"

docker info > /dev/null 2>&1
check_result $? "Docker daemon"

# Step 4: Clean start
print_step "Preparing clean environment..."
docker-compose down --remove-orphans > /dev/null 2>&1 || true
docker system prune -f > /dev/null 2>&1 || true
check_result 0 "Environment cleanup"

# Step 5: Build test
print_step "Testing build process..."
docker-compose build > /dev/null 2>&1
check_result $? "Docker build"

# Step 6: Start services
print_step "Starting services..."
docker-compose up -d > /dev/null 2>&1
check_result $? "Services startup"

# Wait for services
print_step "Waiting for services to initialize..."
sleep 45

# Step 7: Database connectivity
print_step "Testing database connection..."
max_attempts=30
db_ready=1
for i in $(seq 1 $max_attempts); do
    if docker-compose exec -T db pg_isready -U "${DB_USER:-pulsecal_user}" -d "${DB_NAME:-pulsecal_db}" > /dev/null 2>&1; then
        db_ready=0
        break
    fi
    sleep 2
done
check_result $db_ready "Database connection"

# Step 8: Redis connectivity
print_step "Testing Redis connection..."
docker-compose exec -T redis redis-cli ping > /dev/null 2>&1
check_result $? "Redis connection"

# Step 9: Web service health
print_step "Testing web service..."
max_attempts=20
web_ready=1
for i in $(seq 1 $max_attempts); do
    if curl -f -s http://localhost:8000/health/ > /dev/null 2>&1; then
        web_ready=0
        break
    fi
    sleep 3
done
check_result $web_ready "Web service health"

# Step 10: Database operations
print_step "Testing database operations..."
if [ -f test-database.py ]; then
    python3 test-database.py > /dev/null 2>&1
    check_result $? "Database operations"
else
    docker-compose exec -T web python manage.py check > /dev/null 2>&1
    check_result $? "Django system check"
fi

# Step 11: Migrations
print_step "Checking migrations..."
docker-compose exec -T web python manage.py migrate --check > /dev/null 2>&1
migration_status=$?
if [ $migration_status -ne 0 ]; then
    print_status "Applying migrations..."
    docker-compose exec -T web python manage.py migrate --noinput > /dev/null 2>&1
    check_result $? "Migration application"
else
    check_result 0 "Migrations (up to date)"
fi

# Step 12: Static files
print_step "Testing static files..."
docker-compose exec -T web python manage.py collectstatic --noinput --dry-run > /dev/null 2>&1
check_result $? "Static files collection"

# Step 13: Admin interface
print_step "Testing admin interface..."
curl -f -s http://localhost:8000/admin/ > /dev/null 2>&1
check_result $? "Admin interface"

# Step 14: Authentication system
print_step "Testing authentication..."
curl -f -s http://localhost:8000/accounts/login/ > /dev/null 2>&1
check_result $? "Authentication system"

# Step 15: Main application
print_step "Testing main application..."
curl -f -s http://localhost:8000/ > /dev/null 2>&1
check_result $? "Main application"

# Step 16: API endpoints
print_step "Testing API endpoints..."
curl -f -s http://localhost:8000/nearby-clinics/ > /dev/null 2>&1
check_result $? "API endpoints"

# Step 17: Resource usage
print_step "Checking resource usage..."
memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" | head -3 | grep -v "0B" | wc -l)
if [ $memory_usage -ge 3 ]; then
    check_result 0 "Resource usage"
else
    warning_result "Low resource usage detected"
fi

# Step 18: Security headers
print_step "Testing security headers..."
security_headers=$(curl -s -I http://localhost:8000/ | grep -E "(X-Frame-Options|X-Content-Type-Options)" | wc -l)
if [ $security_headers -ge 1 ]; then
    check_result 0 "Security headers"
else
    warning_result "Some security headers missing"
fi

# Step 19: SSL readiness (if certificates exist)
print_step "Checking SSL readiness..."
if [ -f ssl/cert.pem ] && [ -f ssl/key.pem ]; then
    check_result 0 "SSL certificates present"
else
    warning_result "SSL certificates not found (run ssl-setup.sh for production)"
fi

# Step 20: Backup system
print_step "Testing backup system..."
if [ -f backup.sh ]; then
    check_result 0 "Backup script available"
else
    warning_result "Backup script not found"
fi

# Cleanup
print_step "Cleaning up test environment..."
docker-compose down > /dev/null 2>&1

# Final assessment
print_status ""
print_status "🏥 Pre-Deployment Check Results"
print_status "==============================="
print_success "Checks Passed: $CHECKS_PASSED"
if [ $CHECKS_FAILED -gt 0 ]; then
    print_error "Checks Failed: $CHECKS_FAILED"
fi
if [ $WARNINGS -gt 0 ]; then
    print_warning "Warnings: $WARNINGS"
fi

# Deployment recommendation
print_status ""
if [ $CHECKS_FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        print_success "🎉 PERFECT! Ready for production deployment!"
        print_success "✅ All systems operational"
        print_success "✅ No issues detected"
        print_success "✅ Database connectivity confirmed"
        print_success "✅ All services functional"
    else
        print_success "🟡 GOOD! Ready for deployment with minor warnings"
        print_warning "⚠️  $WARNINGS warnings detected (non-critical)"
        print_success "✅ Core functionality working"
    fi
    
    print_status ""
    print_status "🚀 Deployment Commands:"
    print_status "  Fresh deployment: ./fresh-deploy.sh"
    print_status "  Production deployment: ./deploy.sh --production"
    print_status "  AWS Lightsail: ./lightsail-deploy.sh"
    
    exit 0
else
    print_error "❌ NOT READY for deployment!"
    print_error "💥 $CHECKS_FAILED critical issues detected"
    
    print_status ""
    print_status "🔧 Recommended fixes:"
    print_status "1. Check Docker installation and daemon"
    print_status "2. Verify .env file configuration"
    print_status "3. Ensure database credentials are correct"
    print_status "4. Check network connectivity"
    print_status "5. Run ./fix-common-issues.sh again"
    print_status "6. Review Docker Compose logs: docker-compose logs"
    
    exit 1
fi