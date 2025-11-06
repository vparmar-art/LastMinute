#!/bin/bash
# Script to seed VehicleType objects in the database via ECS
# Usage: ./seed_vehicle_types.sh

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

# Create Python script to seed vehicle types
SEED_SCRIPT=$(cat <<'PYTHON_EOF'
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'main.settings')
django.setup()

from vehicles.models import VehicleType

vehicle_types = [
    {'name': 'bike', 'base_fare': 20.00, 'fare_per_km': 5.00, 'capacity_in_kg': 50},
    {'name': 'auto', 'base_fare': 30.00, 'fare_per_km': 8.00, 'capacity_in_kg': 100},
    {'name': 'mini_truck', 'base_fare': 50.00, 'fare_per_km': 12.00, 'capacity_in_kg': 500},
    {'name': 'truck', 'base_fare': 100.00, 'fare_per_km': 20.00, 'capacity_in_kg': 2000},
]

created_count = 0
updated_count = 0

for vt_data in vehicle_types:
    vehicle_type, created = VehicleType.objects.get_or_create(
        name=vt_data['name'],
        defaults={
            'base_fare': vt_data['base_fare'],
            'fare_per_km': vt_data['fare_per_km'],
            'capacity_in_kg': vt_data['capacity_in_kg'],
            'is_active': True
        }
    )
    
    if created:
        print(f"✅ Created vehicle type: {vehicle_type.name}")
        created_count += 1
    else:
        # Update existing if needed
        updated = False
        if vehicle_type.base_fare != vt_data['base_fare']:
            vehicle_type.base_fare = vt_data['base_fare']
            updated = True
        if vehicle_type.fare_per_km != vt_data['fare_per_km']:
            vehicle_type.fare_per_km = vt_data['fare_per_km']
            updated = True
        if vehicle_type.capacity_in_kg != vt_data['capacity_in_kg']:
            vehicle_type.capacity_in_kg = vt_data['capacity_in_kg']
            updated = True
        if not vehicle_type.is_active:
            vehicle_type.is_active = True
            updated = True
        
        if updated:
            vehicle_type.save()
            print(f"🔄 Updated vehicle type: {vehicle_type.name}")
            updated_count += 1
        else:
            print(f"✓ Vehicle type already exists: {vehicle_type.name}")

print(f"\n📊 Summary: Created {created_count}, Updated {updated_count}")
PYTHON_EOF
)

# Save script to temp file
TEMP_SCRIPT=$(mktemp)
echo "$SEED_SCRIPT" > "$TEMP_SCRIPT"

# Run one-time task with seed script
echo "Seeding vehicle types..."
TASK_ARN=$(aws ecs run-task \
    --cluster "$CLUSTER" \
    --task-definition "$TASK_DEFINITION" \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=DISABLED}" \
    --overrides "{
        \"containerOverrides\": [{
            \"name\": \"app\",
            \"command\": [\"python\", \"-c\", \"$(echo "$SEED_SCRIPT" | sed 's/"/\\"/g' | tr '\n' ' ')\"]
        }]
    }" \
    --region "$REGION" \
    --query "tasks[0].taskArn" \
    --output text 2>/dev/null || echo "Failed to start task")

# Clean up temp file
rm "$TEMP_SCRIPT"

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ] || [ "$TASK_ARN" == "Failed to start task" ]; then
    echo "❌ Failed to start seed task"
    echo ""
    echo "Trying alternative method: Using manage.py shell command..."
    
    # Alternative: Use Django shell command
    TASK_ARN=$(aws ecs run-task \
        --cluster "$CLUSTER" \
        --task-definition "$TASK_DEFINITION" \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=DISABLED}" \
        --overrides "{
            \"containerOverrides\": [{
                \"name\": \"app\",
                \"command\": [\"python\", \"manage.py\", \"shell\", \"-c\", \"from vehicles.models import VehicleType; VehicleType.objects.get_or_create(name='bike', defaults={'base_fare': 20.00, 'fare_per_km': 5.00, 'capacity_in_kg': 50, 'is_active': True}); VehicleType.objects.get_or_create(name='auto', defaults={'base_fare': 30.00, 'fare_per_km': 8.00, 'capacity_in_kg': 100, 'is_active': True}); VehicleType.objects.get_or_create(name='mini_truck', defaults={'base_fare': 50.00, 'fare_per_km': 12.00, 'capacity_in_kg': 500, 'is_active': True}); VehicleType.objects.get_or_create(name='truck', defaults={'base_fare': 100.00, 'fare_per_km': 20.00, 'capacity_in_kg': 2000, 'is_active': True}); print('Vehicle types seeded successfully')\"]
            }]
        }" \
        --region "$REGION" \
        --query "tasks[0].taskArn" \
        --output text)
fi

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
        --format short | grep -i "vehicle\|created\|updated\|seeded" || echo "No relevant logs found"
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

