#!/bin/bash

# PulseCal Deployment Verification Script
# Comprehensive testing to ensure no 504 errors, database connectivity, and CSRF functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    print_info "Running test: $test_name"
    
    if eval "$test_command"; then
        print_status "$test_name - PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        print_error "$test_name - FAILED"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Test 1: Container Status
test_containers() {
    local containers=$(docker-compose ps -q)
    local running_containers=$(docker-compose ps -q --status=running)
    
    if [ -z "$containers" ]; then
        echo "No containers found"
        return 1
    fi
    
    if [ "$(echo "$containers" | wc -l)" -eq "$(echo "$running_containers" | wc -l)" ]; then
        echo "All containers are running"
        return 0
    else
        echo "Some containers are not running"
        docker-compose ps
        return 1
    fi
}

# Test 2: Database Connectivity
test_database() {
    if docker-compose exec -T db pg_isready -U pulsecal_user -d pulsecal_db >/dev/null 2>&1; then
        echo "Database is accepting connections"
        return 0
    else
        echo "Database connection failed"
        return 1
    fi
}

# Test 3: Redis Connectivity
test_redis() {
    if docker-compose exec -T redis redis-cli ping | grep -q "PONG"; then
        echo "Redis is responding"
        return 0
    else
        echo "Redis connection failed"
        return 1
    fi
}

# Test 4: Web Application Health
test_web_health() {
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s -m 10 "http://localhost:8000/health/" | grep -q '"status".*"healthy"'; then
            echo "Web application health check passed"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo "Web application health check failed"
    return 1
}

# Test 5: CSRF Token Functionality
test_csrf() {
    local csrf_response=$(curl -s -c /tmp/cookies.txt "http://localhost:8000/")
    if echo "$csrf_response" | grep -q "csrftoken"; then
        echo "CSRF token is present"
        return 0
    else
        echo "CSRF token not found"
        return 1
    fi
}

# Test 6: Database Migrations
test_migrations() {
    if docker-compose exec -T web python manage.py showmigrations --plan | grep -q "\[X\]"; then
        echo "Database migrations are applied"
        return 0
    else
        echo "Database migrations not applied"
        return 1
    fi
}

# Test 7: Static Files
test_static_files() {
    if curl -f -s "http://localhost:8000/static/css/websocket.css" >/dev/null 2>&1; then
        echo "Static files are being served"
        return 0
    else
        echo "Static files not accessible"
        return 1
    fi
}

# Test 8: Admin Interface
test_admin() {
    local admin_response=$(curl -s "http://localhost:8000/admin/")
    if echo "$admin_response" | grep -q "Django administration"; then
        echo "Admin interface is accessible"
        return 0
    else
        echo "Admin interface not accessible"
        return 1
    fi
}

# Test 9: Celery Worker
test_celery() {
    if docker-compose exec -T celery celery -A pulsecal_system inspect ping -d celery@$(docker-compose exec -T celery hostname) >/dev/null 2>&1; then
        echo "Celery worker is responding"
        return 0
    else
        echo "Celery worker not responding"
        return 1
    fi
}

# Test 10: Memory Usage
test_memory() {
    local memory_usage=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep -E "(web|db|redis)" | awk '{print $2}' | sed 's/MiB.*//' | awk '{sum+=$1} END {print sum}')
    
    if [ -z "$memory_usage" ]; then
        echo "Could not determine memory usage"
        return 1
    fi
    
    if [ "$memory_usage" -lt 2048 ]; then
        echo "Memory usage is acceptable: ${memory_usage}MB"
        return 0
    else
        echo "Memory usage is high: ${memory_usage}MB"
        return 1
    fi
}

# Main execution
main() {
    echo "=================================================="
    echo "🔍 PulseCal Deployment Verification"
    echo "=================================================="
    echo ""
    
    # Run all tests
    run_test "Container Status" "test_containers"
    run_test "Database Connectivity" "test_database"
    run_test "Redis Connectivity" "test_redis"
    run_test "Web Application Health" "test_web_health"
    run_test "CSRF Functionality" "test_csrf"
    run_test "Database Migrations" "test_migrations"
    run_test "Static Files" "test_static_files"
    run_test "Admin Interface" "test_admin"
    run_test "Celery Worker" "test_celery"
    run_test "Memory Usage" "test_memory"
    
    echo ""
    echo "=================================================="
    echo "📊 Test Results Summary"
    echo "=================================================="
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        print_status "🎉 All tests passed! Deployment is healthy."
        echo ""
        echo "✅ Your PulseCal deployment is ready for use:"
        echo "   🌐 Application: http://localhost:8000"
        echo "   🔧 Admin: http://localhost:8000/admin"
        echo "   📊 Health: http://localhost:8000/health/"
        echo ""
        exit 0
    else
        print_error "❌ Some tests failed. Please check the issues above."
        echo ""
        echo "🔧 Troubleshooting commands:"
        echo "   docker-compose logs -f"
        echo "   docker-compose ps"
        echo "   docker stats"
        echo ""
        exit 1
    fi
}

# Cleanup function
cleanup() {
    rm -f /tmp/cookies.txt 2>/dev/null || true
}

trap cleanup EXIT

# Run main function
main "$@"