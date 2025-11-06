#!/bin/bash
# Script to seed Recharge Plans and Vehicle Types via Django API
# Usage: ./seed_data.sh [BASE_URL]

set -e

BASE_URL="${1:-http://lastminute-alb-233306800.us-east-1.elb.amazonaws.com}"
BASE_URL="${BASE_URL%/}"  # Remove trailing slash

echo "🌐 Seeding data via API: ${BASE_URL}"
echo "=========================================="
echo ""

# Test connection
echo "Testing API connection..."
if ! curl -s -f "${BASE_URL}/health/" > /dev/null; then
    echo "❌ Failed to connect to API at ${BASE_URL}"
    echo "   Please check if the endpoint is correct and the service is running"
    exit 1
fi
echo "✅ API connection successful"
echo ""

# Function to create recharge plan
create_recharge_plan() {
    local name="$1"
    local amount="$2"
    local ride_credits="$3"
    local duration_days="$4"
    local description="$5"
    
    echo "  Creating: ${name}..."
    
    local json_data
    if [ "$ride_credits" = "null" ]; then
        json_data="{\"name\":\"${name}\",\"amount\":${amount},\"ride_credits\":null,\"duration_days\":${duration_days},\"description\":\"${description}\",\"is_active\":true}"
    else
        json_data="{\"name\":\"${name}\",\"amount\":${amount},\"ride_credits\":${ride_credits},\"duration_days\":${duration_days},\"description\":\"${description}\",\"is_active\":true}"
    fi
    
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/wallet/plans/create/" \
        -H "Content-Type: application/json" \
        -d "${json_data}")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        local created
        created=$(echo "$body" | grep -o '"created":[^,]*' | cut -d':' -f2)
        if [ "$created" = "true" ]; then
            echo "    ✅ Created successfully"
        else
            echo "    ✅ Updated successfully"
        fi
        return 0
    else
        echo "    ❌ Failed (HTTP ${http_code})"
        echo "    Response: ${body}"
        return 1
    fi
}

# Function to create vehicle type
create_vehicle_type() {
    local name="$1"
    local base_fare="$2"
    local fare_per_km="$3"
    local capacity_in_kg="$4"
    
    echo "  Creating: ${name}..."
    
    local json_data="{\"name\":\"${name}\",\"base_fare\":${base_fare},\"fare_per_km\":${fare_per_km},\"capacity_in_kg\":${capacity_in_kg},\"is_active\":true}"
    
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/vehicles/types/create/" \
        -H "Content-Type: application/json" \
        -d "${json_data}")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        local created
        created=$(echo "$body" | grep -o '"created":[^,]*' | cut -d':' -f2)
        if [ "$created" = "true" ]; then
            echo "    ✅ Created successfully"
        else
            echo "    ✅ Updated successfully"
        fi
        return 0
    else
        echo "    ❌ Failed (HTTP ${http_code})"
        echo "    Response: ${body}"
        return 1
    fi
}

# Seed Recharge Plans
echo "💳 Seeding Recharge Plans"
echo "------------------------"
create_recharge_plan "Basic Plan" 99.00 10 30 "10 rides valid for 30 days"
create_recharge_plan "Standard Plan" 299.00 35 30 "35 rides valid for 30 days"
create_recharge_plan "Premium Plan" 499.00 60 30 "60 rides valid for 30 days"
create_recharge_plan "Unlimited Monthly" 999.00 null 30 "Unlimited rides for 30 days"
echo ""

# Seed Vehicle Types
echo "🚗 Seeding Vehicle Types"
echo "------------------------"
create_vehicle_type "bike" 20.00 5.00 50
create_vehicle_type "auto" 30.00 8.00 100
create_vehicle_type "mini_truck" 50.00 12.00 500
create_vehicle_type "truck" 100.00 20.00 2000
echo ""

echo "✅ Done! Data seeding completed."
echo ""
echo "📋 Verify the data:"
echo "   Recharge Plans: ${BASE_URL}/api/wallet/plans/"
echo "   Vehicle Types: ${BASE_URL}/api/vehicles/types/"

