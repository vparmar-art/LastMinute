#!/bin/bash
# Script to run the Django app connected to the cloud database (RDS)
# Usage: ./run_cloud.sh [DB_PASSWORD]

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

# Get password from argument or environment variable
if [ -n "$1" ]; then
    export DB_PASSWORD="$1"
elif [ -z "$DB_PASSWORD" ]; then
    echo "Please provide the database password:"
    read -s DB_PASSWORD
    export DB_PASSWORD
fi

echo "Starting Django server connected to cloud database: $DB_HOST"
echo ""

# Run the server
python manage.py runserver 0.0.0.0:8000

