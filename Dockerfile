# Multi-stage build for production optimization
FROM python:3.11-slim as builder

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies for building
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    gcc \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Production stage
FROM python:3.11-slim as production

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/opt/venv/bin:$PATH"
ENV DJANGO_SETTINGS_MODULE=pulsecal_system.settings

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && apt-get autoremove -y

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Create non-root user for security
RUN groupadd -r pulsecal --gid=1000 && \
    useradd -r -g pulsecal --uid=1000 --home-dir=/app --shell=/bin/bash pulsecal

# Set work directory
WORKDIR /app

# Copy project files
COPY --chown=pulsecal:pulsecal . /app/

# Copy and set up entrypoint script
COPY --chown=pulsecal:pulsecal docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create necessary directories with proper permissions
RUN mkdir -p /app/staticfiles /app/media /app/logs /app/data && \
    chown -R pulsecal:pulsecal /app && \
    chmod -R 755 /app

# Switch to non-root user
USER pulsecal

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health/ || exit 1

# Expose port
EXPOSE 8000

# Production command optimized for low memory (512MB instance)
CMD ["gunicorn", "pulsecal_system.wsgi:application", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "2", \
     "--worker-class", "sync", \
     "--max-requests", "500", \
     "--max-requests-jitter", "50", \
     "--timeout", "30", \
     "--keep-alive", "2", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "--log-level", "warning", \
     "--preload"] 