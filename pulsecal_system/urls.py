"""
URL configuration for pulsecal_system project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
import logging

logger = logging.getLogger(__name__)

@csrf_exempt
@require_http_methods(["GET", "HEAD"])
def health_check(request):
    """
    Comprehensive health check endpoint
    Tests database, cache, and basic application functionality
    """
    try:
        from django.db import connection
        from django.core.cache import cache
        
        # Test database connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            db_status = "ok"
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        db_status = f"error: {str(e)}"
    
    try:
        # Test cache connection
        cache.set('health_check', 'ok', 30)
        cache_result = cache.get('health_check')
        cache_status = "ok" if cache_result == 'ok' else "error"
    except Exception as e:
        logger.error(f"Cache health check failed: {e}")
        cache_status = f"error: {str(e)}"
    
    # Overall health status
    is_healthy = db_status == "ok" and cache_status == "ok"
    
    response_data = {
        "status": "healthy" if is_healthy else "unhealthy",
        "database": db_status,
        "cache": cache_status,
        "version": "1.0.0"
    }
    
    status_code = 200 if is_healthy else 503
    
    return JsonResponse(response_data, status=status_code)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('appointments.urls')),
    path('accounts/', include('allauth.urls')),
    path('health/', health_check, name='health_check'),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)

# Custom error handlers
handler404 = 'appointments.views.custom_404'
handler500 = 'appointments.views.custom_500'