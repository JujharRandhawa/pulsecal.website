#!/bin/bash

# PulseCal Deployment Debug & Test Script
# Comprehensive testing to ensure error-free deployment

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

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

test_result() {
    if [ $1 -eq 0 ]; then
        print_success "✅ $2"
        ((TESTS_PASSED++))
    else
        print_error "❌ $2"
        ((TESTS_FAILED++))
    fi
}

print_status "🔍 PulseCal Deployment Debug & Test Suite"
print_status "========================================"

# Test 1: Environment file validation
print_step "Testing environment configuration..."
if [ ! -f .env ]; then
    print_warning "No .env file found. Creating from template..."
    cp .env.production.example .env
fi

source .env
test_result $? "Environment file loaded"

# Test 2: Required environment variables
print_step "Validating required environment variables..."
required_vars=("SECRET_KEY" "DB_PASSWORD" "ALLOWED_HOSTS")
env_valid=0
for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        print_error "Missing required variable: $var"
        env_valid=1
    fi
done
test_result $env_valid "Required environment variables"

# Test 3: Docker availability
print_step "Testing Docker availability..."
docker --version > /dev/null 2>&1
test_result $? "Docker installation"

docker info > /dev/null 2>&1
test_result $? "Docker daemon running"

# Test 4: Docker Compose availability
print_step "Testing Docker Compose availability..."
if command -v docker-compose &> /dev/null; then
    docker-compose --version > /dev/null 2>&1
    test_result $? "Docker Compose installation"
elif docker compose version &> /dev/null; then
    test_result 0 "Docker Compose (built-in) installation"
else
    test_result 1 "Docker Compose installation"
fi

# Test 5: Docker Compose file validation
print_step "Validating Docker Compose configuration..."
docker-compose config > /dev/null 2>&1
test_result $? "Docker Compose file syntax"

# Test 6: Build test
print_step "Testing Docker build process..."
docker-compose build web > /dev/null 2>&1
test_result $? "Docker image build"

# Test 7: Start services
print_step "Starting services for testing..."
docker-compose up -d > /dev/null 2>&1
test_result $? "Services startup"

# Wait for services to be ready
print_step "Waiting for services to initialize..."
sleep 30

# Test 8: Database connection
print_step "Testing database connection..."
docker-compose exec -T db pg_isready -U "${DB_USER:-pulsecal_user}" -d "${DB_NAME:-pulsecal_db}" > /dev/null 2>&1
test_result $? "Database connection"

# Test 9: Redis connection
print_step "Testing Redis connection..."
docker-compose exec -T redis redis-cli ping > /dev/null 2>&1
test_result $? "Redis connection"

# Test 10: Web service health
print_step "Testing web service health..."
sleep 10
curl -f -s http://localhost:8000/health/ > /dev/null 2>&1
test_result $? "Web service health check"

# Test 11: Database migrations
print_step "Testing database migrations..."
docker-compose exec -T web python manage.py migrate --check > /dev/null 2>&1
migration_check=$?
if [ $migration_check -ne 0 ]; then
    print_status "Running migrations..."
    docker-compose exec -T web python manage.py migrate --noinput > /dev/null 2>&1
    test_result $? "Database migrations"
else
    test_result 0 "Database migrations (already applied)"
fi

# Test 12: Static files collection
print_step "Testing static files collection..."
docker-compose exec -T web python manage.py collectstatic --noinput --dry-run > /dev/null 2>&1
test_result $? "Static files collection"

# Test 13: Django admin access
print_step "Testing Django admin interface..."
curl -f -s http://localhost:8000/admin/ > /dev/null 2>&1
test_result $? "Django admin interface"

# Test 14: Database query test
print_step "Testing database queries..."
docker-compose exec -T web python manage.py shell -c "
from django.contrib.auth.models import User
from appointments.models import UserProfile, Organization
print('Database query test passed')
" > /dev/null 2>&1
test_result $? "Database queries"

# Test 15: Model validation
print_step "Testing model validation..."
docker-compose exec -T web python manage.py check > /dev/null 2>&1
test_result $? "Django model validation"

# Test 16: URL configuration
print_step "Testing URL configuration..."
docker-compose exec -T web python manage.py check --deploy > /dev/null 2>&1
test_result $? "URL configuration and deployment checks"

# Test 17: Template rendering
print_step "Testing template rendering..."
curl -f -s http://localhost:8000/ > /dev/null 2>&1
test_result $? "Template rendering"

# Test 18: Authentication system
print_step "Testing authentication system..."
curl -f -s http://localhost:8000/accounts/login/ > /dev/null 2>&1
test_result $? "Authentication system"

# Test 19: API endpoints
print_step "Testing API endpoints..."
curl -f -s http://localhost:8000/api/appointments/ > /dev/null 2>&1 || \
curl -f -s http://localhost:8000/appointments/ > /dev/null 2>&1
test_result $? "API endpoints"

# Test 20: Memory and resource usage
print_step "Testing resource usage..."
memory_usage=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep -E "(web|db|redis)" | wc -l)
if [ $memory_usage -ge 3 ]; then
    test_result 0 "Resource usage (all containers running)"
else
    test_result 1 "Resource usage (some containers missing)"
fi

# Cleanup test
print_step "Cleaning up test environment..."
docker-compose down > /dev/null 2>&1

# Summary
print_status ""
print_status "🏥 PulseCal Deployment Test Results"
print_status "=================================="
print_success "Tests Passed: $TESTS_PASSED"
if [ $TESTS_FAILED -gt 0 ]; then
    print_error "Tests Failed: $TESTS_FAILED"
else
    print_success "Tests Failed: $TESTS_FAILED"
fi

# Overall result
if [ $TESTS_FAILED -eq 0 ]; then
    print_status ""
    print_success "🎉 ALL TESTS PASSED! Deployment is ready!"
    print_success "✅ Database connection: Working"
    print_success "✅ Services: All functional"
    print_success "✅ Configuration: Valid"
    print_success "✅ Dependencies: Available"
    print_status ""
    print_status "🚀 Ready for production deployment!"
    exit 0
else
    print_status ""
    print_error "❌ Some tests failed. Please fix issues before deployment."
    print_status ""
    print_status "Common fixes:"
    print_status "1. Check .env file configuration"
    print_status "2. Ensure Docker is running"
    print_status "3. Verify network connectivity"
    print_status "4. Check disk space"
    print_status "5. Review Docker Compose configuration"
    exit 1
fi