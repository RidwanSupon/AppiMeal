#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting AppiMeal Production Deployment..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "📦 Docker not found. Installing Docker and Docker Compose..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Ensure .env file exists
if [ ! -f .env ]; then
    echo "⚙️ Creating production .env file from .env.example..."
    cp .env.example .env
    
    # Generate Application Key
    APP_KEY=$(openssl rand -base64 32)
    sed -i "s/APP_KEY=/APP_KEY=base64:${APP_KEY}/g" .env
    sed -i "s/APP_ENV=local/APP_ENV=production/g" .env
    sed -i "s/APP_DEBUG=true/APP_DEBUG=false/g" .env
fi

# Build and launch Docker containers
echo "🐳 Building and starting Docker containers..."
docker compose down || true
docker compose up --build -d

echo "⏳ Waiting for MySQL database to initialize..."
sleep 15

# Run migrations and seed data
echo "🗄️ Running migrations and database seeders..."
docker compose exec -T app php artisan migrate:fresh --seed --force
docker compose exec -T app php artisan storage:link || true
docker compose exec -T app php artisan config:cache
docker compose exec -T app php artisan route:cache
docker compose exec -T app php artisan view:cache

echo "✅ AppiMeal Production Backend successfully deployed!"
echo "🌐 API Endpoint active at: http://YOUR_SERVER_IP:8000/api"
