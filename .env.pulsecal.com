# Production Environment Configuration for pulsecal.com

# Environment
ENVIRONMENT=production
DEBUG=False

# Security
SECRET_KEY=your-super-secret-key-here-change-this-in-production
ALLOWED_HOSTS=pulsecal.com,www.pulsecal.com

# Database
DB_NAME=pulsecal_prod
DB_USER=pulsecal_user
DB_PASSWORD=your-secure-database-password
DB_HOST=localhost
DB_PORT=5432

# CSRF and CORS Settings
CSRF_TRUSTED_ORIGINS=https://pulsecal.com,https://www.pulsecal.com
CORS_ALLOWED_ORIGINS=https://pulsecal.com,https://www.pulsecal.com

# Email Configuration
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=noreply@pulsecal.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=PulseCal Healthcare <noreply@pulsecal.com>

# Google OAuth Settings
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=https://pulsecal.com/accounts/google/login/callback/

# Google Maps API
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
GOOGLE_PLACES_API_KEY=your-google-places-api-key

# Redis Configuration
REDIS_URL=redis://localhost:6379/0

# Sentry (Optional - for error tracking)
SENTRY_DSN=your-sentry-dsn-url

# SSL/TLS Settings (automatically handled when ENVIRONMENT=production)
# SECURE_SSL_REDIRECT=True
# SECURE_HSTS_SECONDS=31536000
# SECURE_HSTS_INCLUDE_SUBDOMAINS=True
# SECURE_HSTS_PRELOAD=True
# SESSION_COOKIE_SECURE=True
# CSRF_COOKIE_SECURE=True