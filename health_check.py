#!/usr/bin/env python
"""
Comprehensive health check script for PulseCal
Tests database, Redis, and application connectivity
"""

import os
import sys
import django
import requests
import time
from pathlib import Path

# Add the project directory to Python path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

# Set Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'pulsecal_system.settings')

try:
    django.setup()
    
    from django.db import connection
    from django.core.cache import cache
    from django.conf import settings
    
    def check_database():
        """Check database connectivity"""
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                return True
        except Exception as e:
            print(f"Database check failed: {e}")
            return False
    
    def check_redis():
        """Check Redis connectivity"""
        try:
            cache.set('health_check', 'ok', 30)
            result = cache.get('health_check')
            return result == 'ok'
        except Exception as e:
            print(f"Redis check failed: {e}")
            return False
    
    def check_application():
        """Check if Django application is responding"""
        try:
            # Try to import a model to ensure Django is properly loaded
            from appointments.models import UserProfile
            return True
        except Exception as e:
            print(f"Application check failed: {e}")
            return False
    
    def main():
        """Run all health checks"""
        checks = [
            ("Database", check_database),
            ("Redis", check_redis),
            ("Application", check_application),
        ]
        
        all_passed = True
        
        for name, check_func in checks:
            try:
                if check_func():
                    print(f"✓ {name} check passed")
                else:
                    print(f"✗ {name} check failed")
                    all_passed = False
            except Exception as e:
                print(f"✗ {name} check error: {e}")
                all_passed = False
        
        if all_passed:
            print("All health checks passed")
            sys.exit(0)
        else:
            print("Some health checks failed")
            sys.exit(1)
    
    if __name__ == "__main__":
        main()

except Exception as e:
    print(f"Health check setup failed: {e}")
    sys.exit(1)