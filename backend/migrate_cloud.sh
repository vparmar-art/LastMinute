#!/bin/bash
# Script to run migrations on the cloud database (RDS)
# Usage: ./migrate_cloud.sh [DB_PASSWORD]

cd "$(dirname "$0")"
source .venv/bin/activate

# Set cloud database connection
export LOCAL_DEV=true  # This bypasses KMS and uses plain env vars
# Using Terraform-managed RDS instance
export DB_HOST='lastminute-pg.c0jy4eimmagt.us-east-1.rds.amazonaws.com'
export DB_NAME='lastminute'
export DB_USER='appuser'
export DB_PORT='5432'
# Password from Terraform/SSM: ]ecq!44]9(4$KbLiv8%6

# Get password from argument, environment variable, or use hardcoded value
if [ -n "$1" ]; then
    export DB_PASSWORD="$1"
elif [ -z "$DB_PASSWORD" ]; then
    # Use hardcoded password from SSM
    export DB_PASSWORD="]ecq!44]9(4\$KbLiv8%6"
fi

echo "Connecting to cloud database: $DB_HOST"
echo ""

# Enable PostGIS extension if not already enabled
echo "Enabling PostGIS extension..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>&1 | grep -v "Password:"
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT PostGIS_version();" 2>&1 | grep -E "postgis_version|3\." | head -1

# Test connection
echo ""
echo "Testing Django connection..."
python manage.py dbshell -c "SELECT version();" 2>&1 | head -3

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Connected successfully!"
    echo ""
    echo "Running migrations..."
    python manage.py migrate
    echo ""
    echo "✅ Migrations complete!"
else
    echo ""
    echo "❌ Failed to connect. Please check your credentials."
    exit 1
fi

