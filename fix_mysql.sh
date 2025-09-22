#!/bin/bash

# Quick fix script for MySQL issues
echo "🔧 Fixing MySQL issues..."

# Stop all containers
echo "Stopping all containers..."
docker stop $(docker ps -aq) 2>/dev/null || true

# Remove MySQL container specifically
echo "Removing MySQL container..."
docker rm -f cls-mysql 2>/dev/null || true

# Remove MySQL data volume
echo "Removing MySQL data volume..."
docker volume rm cls_mysql_data 2>/dev/null || true

# Clean up any orphaned volumes
echo "Cleaning up orphaned volumes..."
docker volume prune -f

# Remove any MySQL-related containers
echo "Removing any MySQL containers..."
docker ps -a --filter "name=mysql" --format "{{.ID}}" | xargs -r docker rm -f

# Clean up networks
echo "Cleaning up networks..."
docker network prune -f

echo "✅ MySQL cleanup completed!"
echo "Now run: ./deploy_docker.sh"
echo "Then select option 5: Pull and start services (without Nginx)"
