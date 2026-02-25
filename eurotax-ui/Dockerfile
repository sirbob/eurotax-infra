# =============================================================================
# eurotax-ui: Multi-stage Dockerfile
# PHP 8.2 / Laravel 12 + React 19 (Inertia.js) with Nginx + PHP-FPM
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Composer — install PHP dependencies
# ---------------------------------------------------------------------------
FROM composer:2 AS composer

WORKDIR /app

# Copy composer files first for layer caching
COPY composer.json composer.lock ./

# Install production dependencies only (no dev, optimized autoloader)
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-scripts \
    --no-autoloader \
    --prefer-dist

# Copy the full application source (needed for autoloader dump)
COPY . .

# Generate optimized autoloader with full source available
RUN composer dump-autoload --optimize --no-dev

# ---------------------------------------------------------------------------
# Stage 2: Frontend — build React/Vite assets with pnpm
# Wayfinder Vite plugin requires PHP + Laravel bootstrap (php artisan)
# Uses composer image as base since it has PHP 8.4 (required by Laravel 12)
# ---------------------------------------------------------------------------
FROM composer:2 AS frontend

# Install Node.js and pnpm for Vite build
RUN apk add --no-cache nodejs npm \
    && npm install -g pnpm

WORKDIR /app

# Copy full app with vendor from composer stage (needed for php artisan wayfinder)
COPY --from=composer /app .

# Install node dependencies (frozen lockfile for reproducibility)
RUN pnpm install --frozen-lockfile

# Build production assets (outputs to public/build/)
# Wayfinder plugin calls php artisan wayfinder:generate during build
RUN pnpm run build

# ---------------------------------------------------------------------------
# Stage 3: Runtime — PHP-FPM + Nginx
# ---------------------------------------------------------------------------
FROM php:8.4-fpm-alpine

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
        nginx \
        curl \
        libpq-dev \
        icu-dev \
        libzip-dev \
        oniguruma-dev \
    && docker-php-ext-install \
        pdo_pgsql \
        pgsql \
        intl \
        zip \
        mbstring \
        opcache \
        pcntl \
    && rm -rf /var/cache/apk/*

# Create non-root user for PHP-FPM
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Configure PHP-FPM to listen on port 9000 and run as appuser
RUN sed -i 's/^user = .*/user = appuser/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/^group = .*/group = appgroup/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' /usr/local/etc/php-fpm.d/www.conf

# Configure PHP opcache for production
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.enable_cli=1'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Configure PHP for production
RUN { \
    echo 'expose_php=Off'; \
    echo 'memory_limit=256M'; \
    echo 'post_max_size=50M'; \
    echo 'upload_max_filesize=50M'; \
    echo 'max_execution_time=30'; \
} > /usr/local/etc/php/conf.d/production.ini

# Configure Nginx
RUN mkdir -p /run/nginx
COPY <<'NGINX_CONF' /etc/nginx/http.d/default.conf
server {
    listen 8000 default_server;
    server_name _;

    root /app/public;
    index index.php;

    charset utf-8;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript image/svg+xml;
    gzip_min_length 256;

    # Handle static assets with long cache
    location /build/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # Favicon and robots
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    # Laravel: route all requests through index.php
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP-FPM handling
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    # Deny access to hidden files
    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Deny access to sensitive files
    location ~* \.(env|log|sql)$ {
        deny all;
    }
}
NGINX_CONF

WORKDIR /app

# Copy PHP dependencies from composer stage
COPY --from=composer /app/vendor ./vendor

# Copy application source code
COPY . .

# Copy built frontend assets from frontend stage (overwrites public/build/)
COPY --from=frontend /app/public/build ./public/build

# Remove Vite hot file (dev artifact) and stale bootstrap cache
RUN rm -f public/hot bootstrap/cache/packages.php bootstrap/cache/services.php

# Create required Laravel directories and set permissions
RUN mkdir -p storage/framework/cache/data \
             storage/framework/sessions \
             storage/framework/views \
             storage/logs \
             bootstrap/cache \
    && chown -R appuser:appgroup storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Expose the application port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# Entrypoint: run migrations, cache config, then start PHP-FPM + Nginx
COPY <<'ENTRYPOINT_SCRIPT' /entrypoint.sh
#!/bin/sh
set -e

# Generate app key if not set
if [ -z "$APP_KEY" ]; then
    php artisan key:generate --force
fi

# Run Laravel optimizations
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Run database migrations
php artisan migrate --force

# Fix storage permissions (in case volumes are mounted)
chown -R appuser:appgroup /app/storage /app/bootstrap/cache 2>/dev/null || true

# Start PHP-FPM in background and Nginx in foreground
php-fpm -D
exec nginx -g 'daemon off;'
ENTRYPOINT_SCRIPT

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
