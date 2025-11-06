#!/bin/bash
# Script to run Django migrations in ECS
# Usage: ./run_migrations_ecs.sh

set -e

CLUSTER="lastminute-us-east-1-cluster"
TASK_DEFINITION="last-minute-task"
REGION="us-east-1"
SUBNET_ID=""  # Will be auto-detected
SECURITY_GROUP_ID=""  # Will be auto-detected

echo "🔄 Running Django Migrations in ECS"
echo "===================================="
echo ""

# Get subnet and security group from ECS service
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

# Run one-time task with migrate command
echo "Starting migration task..."
TASK_ARN=$(aws ecs run-task \
    --cluster "$CLUSTER" \
    --task-definition "$TASK_DEFINITION" \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=DISABLED}" \
    --overrides '{
        "containerOverrides": [{
            "name": "app",
            "command": ["python", "manage.py", "migrate", "--noinput"]
        }]
    }' \
    --region "$REGION" \
    --query "tasks[0].taskArn" \
    --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
    echo "❌ Failed to start migration task"
    exit 1
fi

echo "✅ Migration task started: $TASK_ARN"
echo ""
echo "Waiting for task to complete..."
echo "(This may take a few minutes)"

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
    echo "✅ Migrations completed successfully!"
    
    # Show logs
    echo ""
    echo "📋 Migration logs:"
    aws logs tail "/ecs/last-minute-backend" \
        --region "$REGION" \
        --since 5m \
        --format short | grep -i "migrate\|apply\|create\|alter" || echo "No migration logs found"
else
    echo ""
    echo "❌ Migration failed with exit code: $EXIT_CODE"
    echo ""
    echo "📋 Error logs:"
    aws logs tail "/ecs/last-minute-backend" \
        --region "$REGION" \
        --since 5m \
        --format short | tail -50
    exit 1
fi

