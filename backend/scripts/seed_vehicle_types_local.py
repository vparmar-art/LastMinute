#!/usr/bin/env python
"""
Script to seed VehicleType objects in the local database
Usage: python scripts/seed_vehicle_types_local.py
"""

import os
import sys
import django

# Add the backend directory to the path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Set up Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'main.settings')
django.setup()

from vehicles.models import VehicleType

def seed_vehicle_types():
    """Seed vehicle types in the database"""
    
    vehicle_types = [
        {
            'name': 'bike',
            'base_fare': 20.00,
            'fare_per_km': 5.00,
            'capacity_in_kg': 50,
            'is_active': True
        },
        {
            'name': 'auto',
            'base_fare': 30.00,
            'fare_per_km': 8.00,
            'capacity_in_kg': 100,
            'is_active': True
        },
        {
            'name': 'mini_truck',
            'base_fare': 50.00,
            'fare_per_km': 12.00,
            'capacity_in_kg': 500,
            'is_active': True
        },
        {
            'name': 'truck',
            'base_fare': 100.00,
            'fare_per_km': 20.00,
            'capacity_in_kg': 2000,
            'is_active': True
        },
    ]
    
    created_count = 0
    updated_count = 0
    
    print("🚗 Seeding Vehicle Types")
    print("=" * 50)
    print()
    
    for vt_data in vehicle_types:
        vehicle_type, created = VehicleType.objects.get_or_create(
            name=vt_data['name'],
            defaults={
                'base_fare': vt_data['base_fare'],
                'fare_per_km': vt_data['fare_per_km'],
                'capacity_in_kg': vt_data['capacity_in_kg'],
                'is_active': vt_data['is_active']
            }
        )
        
        if created:
            print(f"✅ Created: {vehicle_type.name} (Base: ₹{vehicle_type.base_fare}, Per km: ₹{vehicle_type.fare_per_km}, Capacity: {vehicle_type.capacity_in_kg}kg)")
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
            if vehicle_type.is_active != vt_data['is_active']:
                vehicle_type.is_active = vt_data['is_active']
                updated = True
            
            if updated:
                vehicle_type.save()
                print(f"🔄 Updated: {vehicle_type.name} (Base: ₹{vehicle_type.base_fare}, Per km: ₹{vehicle_type.fare_per_km}, Capacity: {vehicle_type.capacity_in_kg}kg)")
                updated_count += 1
            else:
                print(f"✓ Already exists: {vehicle_type.name} (Base: ₹{vehicle_type.base_fare}, Per km: ₹{vehicle_type.fare_per_km}, Capacity: {vehicle_type.capacity_in_kg}kg)")
    
    print()
    print("=" * 50)
    print(f"📊 Summary: Created {created_count}, Updated {updated_count}")
    print()
    
    # List all vehicle types
    print("📋 All Vehicle Types:")
    all_types = VehicleType.objects.all().order_by('name')
    for vt in all_types:
        status = "Active" if vt.is_active else "Inactive"
        print(f"  - {vt.name}: ₹{vt.base_fare} base + ₹{vt.fare_per_km}/km, {vt.capacity_in_kg}kg capacity ({status})")

if __name__ == '__main__':
    seed_vehicle_types()

