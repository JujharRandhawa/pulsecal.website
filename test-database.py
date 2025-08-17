#!/usr/bin/env python3

"""
PulseCal Database Connection Test
Tests database connectivity and model integrity
"""

import os
import sys
import django
from pathlib import Path

# Add the project directory to Python path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

# Set Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'pulsecal_system.settings')

try:
    django.setup()
except Exception as e:
    print(f"❌ Django setup failed: {e}")
    sys.exit(1)

from django.db import connection, transaction
from django.core.management import execute_from_command_line
from django.contrib.auth.models import User
from appointments.models import (
    UserProfile, Organization, Appointment, MedicalRecord, 
    Prescription, Insurance, Payment, EmergencyContact,
    MedicationReminder, TelemedicineSession, ChatRoom, 
    ChatMessage, AuditLog, DoctorOrganizationJoinRequest
)

def test_database_connection():
    """Test basic database connectivity"""
    print("🔍 Testing database connection...")
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT version()")
            version = cursor.fetchone()[0]
            print(f"✅ Database connected: {version}")
            return True
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False

def test_model_creation():
    """Test model creation and basic operations"""
    print("🔍 Testing model operations...")
    
    try:
        # Test User model
        user_count = User.objects.count()
        print(f"✅ User model accessible: {user_count} users")
        
        # Test all custom models
        models_to_test = [
            (UserProfile, "UserProfile"),
            (Organization, "Organization"),
            (Appointment, "Appointment"),
            (MedicalRecord, "MedicalRecord"),
            (Prescription, "Prescription"),
            (Insurance, "Insurance"),
            (Payment, "Payment"),
            (EmergencyContact, "EmergencyContact"),
            (MedicationReminder, "MedicationReminder"),
            (TelemedicineSession, "TelemedicineSession"),
            (ChatRoom, "ChatRoom"),
            (ChatMessage, "ChatMessage"),
            (AuditLog, "AuditLog"),
            (DoctorOrganizationJoinRequest, "DoctorOrganizationJoinRequest"),
        ]
        
        for model, name in models_to_test:
            try:
                count = model.objects.count()
                print(f"✅ {name} model accessible: {count} records")
            except Exception as e:
                print(f"❌ {name} model error: {e}")
                return False
        
        return True
    except Exception as e:
        print(f"❌ Model testing failed: {e}")
        return False

def test_migrations():
    """Test if migrations are applied"""
    print("🔍 Testing migrations...")
    try:
        from django.db.migrations.executor import MigrationExecutor
        executor = MigrationExecutor(connection)
        plan = executor.migration_plan(executor.loader.graph.leaf_nodes())
        
        if plan:
            print(f"⚠️  Unapplied migrations found: {len(plan)}")
            for migration, backwards in plan:
                print(f"   - {migration}")
            return False
        else:
            print("✅ All migrations applied")
            return True
    except Exception as e:
        print(f"❌ Migration check failed: {e}")
        return False

def test_create_sample_data():
    """Test creating sample data"""
    print("🔍 Testing sample data creation...")
    try:
        with transaction.atomic():
            # Create test organization
            org, created = Organization.objects.get_or_create(
                name="Test Clinic",
                defaults={
                    'org_type': 'clinic',
                    'address': 'Test Address',
                    'city': 'Test City',
                    'country': 'Test Country'
                }
            )
            print(f"✅ Organization: {'created' if created else 'exists'}")
            
            # Create test user
            user, created = User.objects.get_or_create(
                username="testuser",
                defaults={
                    'email': 'test@example.com',
                    'first_name': 'Test',
                    'last_name': 'User'
                }
            )
            print(f"✅ User: {'created' if created else 'exists'}")
            
            # Create test profile
            profile, created = UserProfile.objects.get_or_create(
                user=user,
                defaults={
                    'role': 'patient',
                    'organization': org,
                    'phone': '+1234567890'
                }
            )
            print(f"✅ UserProfile: {'created' if created else 'exists'}")
            
            return True
    except Exception as e:
        print(f"❌ Sample data creation failed: {e}")
        return False

def test_queries():
    """Test common database queries"""
    print("🔍 Testing database queries...")
    try:
        # Test joins
        profiles_with_orgs = UserProfile.objects.select_related('organization').count()
        print(f"✅ Join query: {profiles_with_orgs} profiles with organizations")
        
        # Test filtering
        patients = UserProfile.objects.filter(role='patient').count()
        print(f"✅ Filter query: {patients} patients")
        
        # Test aggregation
        from django.db.models import Count
        org_counts = Organization.objects.annotate(
            member_count=Count('members')
        ).count()
        print(f"✅ Aggregation query: {org_counts} organizations with member counts")
        
        return True
    except Exception as e:
        print(f"❌ Query testing failed: {e}")
        return False

def main():
    """Main test function"""
    print("🏥 PulseCal Database Test Suite")
    print("==============================")
    
    tests = [
        test_database_connection,
        test_migrations,
        test_model_creation,
        test_create_sample_data,
        test_queries,
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"❌ Test {test.__name__} crashed: {e}")
            failed += 1
        print()
    
    print("📊 Test Results")
    print("===============")
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    
    if failed == 0:
        print("\n🎉 All database tests passed!")
        print("✅ Database is ready for deployment")
        return 0
    else:
        print(f"\n💥 {failed} tests failed!")
        print("❌ Database needs attention before deployment")
        return 1

if __name__ == "__main__":
    sys.exit(main())