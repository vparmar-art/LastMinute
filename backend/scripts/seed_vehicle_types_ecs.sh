#!/bin/bash
# Script to seed VehicleType objects in the database via ECS
# Usage: ./seed_vehicle_types_ecs.sh

set -e

CLUSTER="lastminute-us-east-1-cluster"
TASK_DEFINITION="last-minute-task"
REGION="us-east-1"

echo "🚗 Seeding Vehicle Types in Database"
echo "===================================="
echo ""

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

# Run one-time task with Django shell command to seed vehicle types
echo "Seeding vehicle types..."
PYTHON_CMD="from vehicles.models import VehicleType; \
VehicleType.objects.get_or_create(name='bike', defaults={'base_fare': 20.00, 'fare_per_km': 5.00, 'capacity_in_kg': 50, 'is_active': True}); \
VehicleType.objects.get_or_create(name='auto', defaults={'base_fare': 30.00, 'fare_per_km': 8.00, 'capacity_in_kg': 100, 'is_active': True}); \
VehicleType.objects.get_or_create(name='mini_truck', defaults={'base_fare': 50.00, 'fare_per_km': 12.00, 'capacity_in_kg': 500, 'is_active': True}); \
VehicleType.objects.get_or_create(name='truck', defaults={'base_fare': 100.00, 'fare_per_km': 20.00, 'capacity_in_kg': 2000, 'is_active': True}); \
print('✅ Vehicle types seeded successfully')"

TASK_ARN=$(aws ecs run-task \
    --cluster "$CLUSTER" \
    --task-definition "$TASK_DEFINITION" \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=DISABLED}" \
    --overrides "{
        \"containerOverrides\": [{
            \"name\": \"app\",
            \"command\": [\"python\", \"manage.py\", \"shell\", \"-c\", \"$PYTHON_CMD\"]
        }]
    }" \
    --region "$REGION" \
    --query "tasks[0].taskArn" \
    --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
    echo "❌ Failed to start seed task"
    exit 1
fi

echo "✅ Seed task started: $TASK_ARN"
echo ""
echo "Waiting for task to complete..."

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
    echo "✅ Vehicle types seeded successfully!"
    echo ""
    echo "📋 Logs:"
    aws logs tail "/ecs/last-minute-backend" \
        --region "$REGION" \
        --since 2m \
        --format short | grep -i "vehicle\|created\|seeded\|success" || echo "No relevant logs found"
else
    echo ""
    echo "❌ Seed task failed with exit code: $EXIT_CODE"
    echo ""
    echo "📋 Error logs:"
    aws logs tail "/ecs/last-minute-backend" \
        --region "$REGION" \
        --since 2m \
        --format short | tail -30
    exit 1
fi

