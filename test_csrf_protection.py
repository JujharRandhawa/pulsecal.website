#!/usr/bin/env python
"""
CSRF Protection Test Script for PulseCal
Tests CSRF protection across the application
"""

import os
import sys
import django
from django.test import TestCase, Client
from django.contrib.auth.models import User
from django.urls import reverse

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'pulsecal_system.settings')
django.setup()

class CSRFProtectionTest(TestCase):
    """Test CSRF protection across the application"""
    
    def setUp(self):
        self.client = Client(enforce_csrf_checks=True)
        self.user = User.objects.create_user(
            username='testuser',
            password='testpass123',
            email='test@example.com'
        )
    
    def test_login_form_csrf_protection(self):
        """Test that login form requires CSRF token"""
        response = self.client.post('/login/', {
            'username': 'testuser',
            'password': 'testpass123'
        })
        # Should fail without CSRF token
        self.assertEqual(response.status_code, 403)
    
    def test_appointment_creation_csrf_protection(self):
        """Test that appointment creation requires CSRF token"""
        self.client.login(username='testuser', password='testpass123')
        response = self.client.post('/appointments/create/', {
            'patient': self.user.id,
            'appointment_date': '2024-12-31 10:00:00'
        })
        # Should fail without CSRF token
        self.assertEqual(response.status_code, 403)
    
    def test_api_endpoints_csrf_protection(self):
        """Test that API endpoints require CSRF token"""
        self.client.login(username='testuser', password='testpass123')
        
        # Test queue status API
        response = self.client.post('/api/queue-status/')
        self.assertEqual(response.status_code, 403)
        
        # Test locations API
        response = self.client.post('/api/locations/')
        self.assertEqual(response.status_code, 403)
    
    def test_valid_csrf_token_allows_request(self):
        """Test that valid CSRF token allows request"""
        # Get CSRF token
        response = self.client.get('/login/')
        csrf_token = response.context['csrf_token']
        
        # Use token in POST request
        response = self.client.post('/login/', {
            'username': 'testuser',
            'password': 'testpass123',
            'csrfmiddlewaretoken': csrf_token
        })
        # Should not be blocked by CSRF (may fail for other reasons)
        self.assertNotEqual(response.status_code, 403)

def run_csrf_tests():
    """Run CSRF protection tests"""
    print("🔒 Running CSRF Protection Tests...")
    print("=" * 50)
    
    # Import test modules
    from django.test.utils import get_runner
    from django.conf import settings
    
    # Get test runner
    TestRunner = get_runner(settings)
    test_runner = TestRunner()
    
    # Run tests
    failures = test_runner.run_tests(['test_csrf_protection'])
    
    if failures:
        print(f"❌ {failures} test(s) failed")
        return False
    else:
        print("✅ All CSRF protection tests passed!")
        return True

if __name__ == '__main__':
    success = run_csrf_tests()
    sys.exit(0 if success else 1)