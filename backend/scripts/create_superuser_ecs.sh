#!/bin/bash
# Script to create Django superuser in ECS
# Usage: ./create_superuser_ecs.sh [username] [email] [password]

set -e

CLUSTER="lastminute-us-east-1-cluster"
TASK_DEFINITION="last-minute-task"
REGION="us-east-1"

echo "👤 Creating Django Superuser in ECS"
echo "===================================="
echo ""

# Get credentials from arguments or prompt
if [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ]; then
    USERNAME="$1"
    EMAIL="$2"
    PASSWORD="$3"
else
    echo "Enter superuser credentials:"
    echo ""
    read -p "Username: " USERNAME
    read -p "Email: " EMAIL
    read -s -p "Password: " PASSWORD
    echo ""
    echo ""
fi

if [ -z "$USERNAME" ] || [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
    echo "❌ Error: Username, email, and password are required"
    exit 1
fi

# Get network configuration from ECS service
echo "Getting network configuration from ECS service..."
SERVICE_INFO=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services lastminute-svc \
    --region "$REGION" \
    --query "services[0].networkConfiguration.awsvpcConfiguration" \
    --output json)

SUBNET_IDS=$(echo "$SERVICE_INFO" | jq -r '.subnets[]' | head -1)
SECURITY_GROUPS=$(echo "$SERVICE_INFO" | jq -r '.securityGroups[]' | head -1)

if [ -z "$SUBNET_IDS" ] || [ -z "$SECURITY_GROUPS" ]; then
    echo "❌ Could not get network configuration from ECS service"
    exit 1
fi

echo "✅ Using subnet: $SUBNET_IDS"
echo "✅ Using security group: $SECURITY_GROUPS"
echo ""

# Run one-time task with createsuperuser command
echo "Creating superuser: $USERNAME"
echo ""

# Escape password for JSON
ESCAPED_PASSWORD=$(echo "$PASSWORD" | sed 's/"/\\"/g')

TASK_ARN=$(aws ecs run-task \
    --cluster "$CLUSTER" \
    --task-definition "$TASK_DEFINITION" \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=DISABLED}" \
    --overrides "{
        \"containerOverrides\": [{
            \"name\": \"app\",
            \"environment\": [
                {\"name\": \"DJANGO_SUPERUSER_USERNAME\", \"value\": \"$USERNAME\"},
                {\"name\": \"DJANGO_SUPERUSER_EMAIL\", \"value\": \"$EMAIL\"},
                {\"name\": \"DJANGO_SUPERUSER_PASSWORD\", \"value\": \"$ESCAPED_PASSWORD\"}
            ],
            \"command\": [\"python\", \"manage.py\", \"createsuperuser\", \"--noinput\"]
        }]
    }" \
    --region "$REGION" \
    --query "tasks[0].taskArn" \
    --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
    echo "❌ Failed to start superuser creation task"
    exit 1
fi

echo "✅ Superuser creation task started: $TASK_ARN"
echo ""
echo "Waiting for task to complete..."
echo "(This may take a minute)"

# Wait for task to complete
aws ecs wait tasks-stopped \
    --cluster "$CLUSTER" \
    --tasks "$TASK_ARN" \
    --region "$REGION"

# Get task exit code
EXIT_CODE=$(aws ecs describe-tasks \
    --cluster "$CLUSTER" \
    --tasks "$TASK_ARN" \
    --region "$REGION" \
    --query "tasks[0].containers[0].exitCode" \
    --output text)

if [ "$EXIT_CODE" == "0" ]; then
    echo ""
    echo "✅ Superuser created successfully!"
    echo ""
    echo "📋 Logs:"
    aws logs tail "/ecs/last-minute-backend" \
        --region "$REGION" \
        --since 2m \
        --format short | grep -i "superuser\|created\|error" || echo "No relevant logs found"
else
    echo ""
    echo "❌ Superuser creation failed with exit code: $EXIT_CODE"
    echo ""
    echo "📋 Error logs:"
    aws logs tail "/ecs/last-minute-backend" \
        --region "$REGION" \
        --since 2m \
        --format short | tail -30
    
    # Check if user already exists
    if aws logs tail "/ecs/last-minute-backend" \
        --region "$REGION" \
        --since 2m \
        --format short | grep -qi "already exists\|unique\|duplicate"; then
        echo ""
        echo "ℹ️  Note: User might already exist. Try a different username."
    fi
    exit 1
fi

