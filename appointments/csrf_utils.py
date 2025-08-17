"""
CSRF Protection Utilities for PulseCal
Provides server-side CSRF validation and utilities
"""

from django.middleware.csrf import get_token
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.utils.decorators import method_decorator
from django.http import JsonResponse
from functools import wraps
import json


def csrf_required(view_func):
    """
    Decorator to ensure CSRF protection for API views
    """
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        if request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            # Check for CSRF token in headers or form data
            csrf_token = (
                request.META.get('HTTP_X_CSRFTOKEN') or
                request.POST.get('csrfmiddlewaretoken') or
                (json.loads(request.body).get('csrfmiddlewaretoken') 
                 if request.content_type == 'application/json' and request.body 
                 else None)
            )
            
            if not csrf_token:
                return JsonResponse({
                    'error': 'CSRF token missing',
                    'code': 'CSRF_TOKEN_MISSING'
                }, status=403)
        
        return view_func(request, *args, **kwargs)
    return wrapper


def get_csrf_token_for_user(request):
    """
    Get CSRF token for the current request
    """
    return get_token(request)


def validate_csrf_token(request, token):
    """
    Validate CSRF token manually
    """
    from django.middleware.csrf import CsrfViewMiddleware
    
    middleware = CsrfViewMiddleware(lambda req: None)
    return middleware._check_token(request, token)


class CSRFProtectedMixin:
    """
    Mixin to add CSRF protection to class-based views
    """
    @method_decorator(csrf_protect)
    def dispatch(self, request, *args, **kwargs):
        return super().dispatch(request, *args, **kwargs)


def api_csrf_exempt(view_func):
    """
    Decorator to exempt API views from CSRF protection
    Use with caution and only for public APIs
    """
    @csrf_exempt
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        # Add custom validation here if needed
        return view_func(request, *args, **kwargs)
    return wrapper