#!/bin/bash
# Script to seed data on ECS using Django management commands
# This can be run via ECS exec or as a one-off task

set -e

echo "🌱 Seeding Recharge Plans and Vehicle Types"
echo "==========================================="
echo ""

# Run management commands
echo "💳 Seeding Recharge Plans..."
python manage.py seed_recharge_plans

echo ""
echo "🚗 Seeding Vehicle Types..."
python manage.py seed_vehicle_types

echo ""
echo "✅ Done!"

