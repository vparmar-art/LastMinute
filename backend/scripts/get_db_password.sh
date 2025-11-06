#!/bin/bash
# Script to retrieve database password from SSM Parameter Store
# Usage: ./get_db_password.sh

set -e

REGION="us-east-1"
PARAMETER_NAME="/lastminute/DATABASE_URL"

echo "🔐 Retrieving Database Password from SSM"
echo "========================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Get DATABASE_URL from SSM
DATABASE_URL=$(aws ssm get-parameter \
    --name "${PARAMETER_NAME}" \
    --region "${REGION}" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text 2>/dev/null)

if [ -z "$DATABASE_URL" ]; then
    echo "❌ DATABASE_URL parameter not found at ${PARAMETER_NAME}"
    echo ""
    echo "Alternative: Check if DB_PASSWORD parameter exists:"
    aws ssm get-parameter \
        --name "/lastminute/DB_PASSWORD" \
        --region "${REGION}" \
        --with-decryption \
        --query "Parameter.Value" \
        --output text 2>/dev/null || echo "   DB_PASSWORD parameter also not found"
    exit 1
fi

# Extract password from DATABASE_URL (format: postgres://user:password@host:port/dbname)
PASSWORD=$(echo "$DATABASE_URL" | sed 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/')
USER=$(echo "$DATABASE_URL" | sed 's/.*:\/\/\([^:]*\):.*/\1/')
HOST=$(echo "$DATABASE_URL" | sed 's/.*@\([^:]*\):.*/\1/')
PORT=$(echo "$DATABASE_URL" | sed 's/.*:\([0-9]*\)\/.*/\1/')
DB=$(echo "$DATABASE_URL" | sed 's/.*\/\([^?]*\).*/\1/')

echo "✅ Database credentials retrieved:"
echo ""
echo "   Host:     $HOST"
echo "   Port:     $PORT"
echo "   Database: $DB"
echo "   User:     $USER"
echo "   Password: $PASSWORD"
echo ""
echo "To use this password:"
echo "   export DB_PASSWORD=\"$PASSWORD\""
echo ""
echo "Or connect directly:"
echo "   psql -h $HOST -U $USER -d $DB"
echo "   (Enter password when prompted: $PASSWORD)"

