"""
Enhanced views for PulseCal appointments app with proper error handling
"""

from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.auth import login, authenticate
from django.contrib import messages
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt, ensure_csrf_cookie
from django.views.decorators.http import require_http_methods
from django.core.exceptions import ValidationError
from django.db import transaction
from django.conf import settings
import logging

logger = logging.getLogger(__name__)

def home(request):
    """Home page view with proper error handling"""
    try:
        context = {
            'title': 'PulseCal Healthcare Management System',
            'description': 'Complete healthcare management solution'
        }
        return render(request, 'appointments/home.html', context)
    except Exception as e:
        logger.error(f"Error in home view: {e}")
        return render(request, 'appointments/home.html', {'error': 'Unable to load home page'})

@login_required
def dashboard(request):
    """Dashboard view with proper error handling"""
    try:
        context = {
            'user': request.user,
            'title': 'Dashboard'
        }
        return render(request, 'appointments/dashboard.html', context)
    except Exception as e:
        logger.error(f"Error in dashboard view: {e}")
        messages.error(request, 'Unable to load dashboard')
        return redirect('home')

@ensure_csrf_cookie
def login_view(request):
    """Login view with CSRF protection"""
    if request.method == 'POST':
        try:
            username = request.POST.get('username')
            password = request.POST.get('password')
            
            if not username or not password:
                messages.error(request, 'Please provide both username and password')
                return render(request, 'appointments/login.html')
            
            user = authenticate(request, username=username, password=password)
            if user is not None:
                login(request, user)
                messages.success(request, 'Successfully logged in')
                return redirect('dashboard')
            else:
                messages.error(request, 'Invalid credentials')
                
        except Exception as e:
            logger.error(f"Error in login view: {e}")
            messages.error(request, 'Login failed due to system error')
    
    return render(request, 'appointments/login.html')

@require_http_methods(["GET"])
def health_check(request):
    """Health check endpoint for monitoring"""
    try:
        from django.db import connection
        from django.core.cache import cache
        
        # Test database
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            db_status = "ok"
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        db_status = f"error: {str(e)}"
    
    try:
        # Test cache
        cache.set('health_check', 'ok', 30)
        cache_result = cache.get('health_check')
        cache_status = "ok" if cache_result == 'ok' else "error"
    except Exception as e:
        logger.error(f"Cache health check failed: {e}")
        cache_status = f"error: {str(e)}"
    
    is_healthy = db_status == "ok" and cache_status == "ok"
    
    response_data = {
        "status": "healthy" if is_healthy else "unhealthy",
        "database": db_status,
        "cache": cache_status,
        "version": "1.0.0"
    }
    
    status_code = 200 if is_healthy else 503
    return JsonResponse(response_data, status=status_code)

def custom_404(request, exception):
    """Custom 404 error handler"""
    return render(request, 'appointments/404.html', status=404)

def custom_500(request):
    """Custom 500 error handler"""
    return render(request, 'appointments/500.html', status=500)

@csrf_exempt
@require_http_methods(["GET", "POST"])
def csrf_token_view(request):
    """Provide CSRF token for AJAX requests"""
    from django.middleware.csrf import get_token
    
    if request.method == 'GET':
        token = get_token(request)
        return JsonResponse({'csrfToken': token})
    
    return JsonResponse({'status': 'ok'})

# Additional views for testing and debugging
def test_db_connection(request):
    """Test database connection"""
    try:
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT version()")
            version = cursor.fetchone()[0]
        return JsonResponse({'status': 'ok', 'database_version': version})
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)

def test_cache_connection(request):
    """Test cache connection"""
    try:
        from django.core.cache import cache
        cache.set('test_key', 'test_value', 30)
        result = cache.get('test_key')
        return JsonResponse({'status': 'ok', 'cache_test': result})
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)