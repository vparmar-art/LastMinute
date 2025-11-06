#!/usr/bin/env python3
"""
Script to seed Recharge Plans and Vehicle Types via Django API
Usage: python scripts/seed_data_via_api.py [--base-url BASE_URL]
"""

import requests
import json
import sys
import argparse
from typing import Dict, List, Any

BASE_URL = "http://lastminute-alb-233306800.us-east-1.elb.amazonaws.com"

def seed_recharge_plans(base_url: str) -> None:
    """Seed recharge plans via API"""
    
    plans = [
        {
            'name': 'Basic Plan',
            'amount': 99.00,
            'ride_credits': 10,
            'duration_days': 30,
            'description': '10 rides valid for 30 days',
            'is_active': True
        },
        {
            'name': 'Standard Plan',
            'amount': 299.00,
            'ride_credits': 35,
            'duration_days': 30,
            'description': '35 rides valid for 30 days',
            'is_active': True
        },
        {
            'name': 'Premium Plan',
            'amount': 499.00,
            'ride_credits': 60,
            'duration_days': 30,
            'description': '60 rides valid for 30 days',
            'is_active': True
        },
        {
            'name': 'Unlimited Monthly',
            'amount': 999.00,
            'ride_credits': None,
            'duration_days': 30,
            'description': 'Unlimited rides for 30 days',
            'is_active': True
        },
    ]
    
    print("💳 Seeding Recharge Plans via API")
    print("=" * 50)
    print()
    
    # First, get existing plans to check what already exists
    try:
        response = requests.get(f"{base_url}/api/wallet/plans/", timeout=10)
        if response.status_code == 200:
            existing_plans = response.json()
            existing_names = {plan.get('name') for plan in existing_plans}
            print(f"Found {len(existing_plans)} existing plans")
        else:
            existing_names = set()
            print(f"Warning: Could not fetch existing plans (status {response.status_code})")
    except Exception as e:
        existing_names = set()
        print(f"Warning: Could not fetch existing plans: {e}")
    
    created_count = 0
    updated_count = 0
    skipped_count = 0
    error_count = 0
    
    print("\n📋 Creating/updating plans:")
    for plan_data in plans:
        rides = f"{plan_data['ride_credits']} rides" if plan_data['ride_credits'] else "Unlimited rides"
        
        if plan_data['name'] in existing_names:
            print(f"  🔄 Updating: {plan_data['name']} - ₹{plan_data['amount']} ({rides}, {plan_data['duration_days']} days)")
        else:
            print(f"  ➕ Creating: {plan_data['name']} - ₹{plan_data['amount']} ({rides}, {plan_data['duration_days']} days)")
        
        try:
            response = requests.post(
                f"{base_url}/api/wallet/plans/create/",
                json=plan_data,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get('created'):
                    print(f"     ✅ Created successfully (ID: {result['plan']['id']})")
                    created_count += 1
                else:
                    print(f"     ✅ Updated successfully (ID: {result['plan']['id']})")
                    updated_count += 1
            else:
                error_msg = response.json().get('error', f'Status {response.status_code}')
                print(f"     ❌ Failed: {error_msg}")
                error_count += 1
        except Exception as e:
            print(f"     ❌ Error: {e}")
            error_count += 1
    
    print()
    print("=" * 50)
    print(f"📊 Summary: {created_count} created, {updated_count} updated, {error_count} errors")
    print()

def seed_vehicle_types(base_url: str) -> None:
    """Seed vehicle types via API"""
    
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
    
    print("🚗 Seeding Vehicle Types via API")
    print("=" * 50)
    print()
    
    # Get existing vehicle types
    try:
        response = requests.get(f"{base_url}/api/vehicles/types/", timeout=10)
        if response.status_code == 200:
            existing_types = response.json()
            existing_names = {vt.get('name') for vt in existing_types}
            print(f"Found {len(existing_types)} existing vehicle types")
        else:
            existing_names = set()
            print(f"Warning: Could not fetch existing vehicle types (status {response.status_code})")
    except Exception as e:
        existing_names = set()
        print(f"Warning: Could not fetch existing vehicle types: {e}")
    
    created_count = 0
    updated_count = 0
    skipped_count = 0
    error_count = 0
    
    print("\n📋 Creating/updating vehicle types:")
    for vt_data in vehicle_types:
        if vt_data['name'] in existing_names:
            print(f"  🔄 Updating: {vt_data['name']} (Base: ₹{vt_data['base_fare']}, Per km: ₹{vt_data['fare_per_km']}, Capacity: {vt_data['capacity_in_kg']}kg)")
        else:
            print(f"  ➕ Creating: {vt_data['name']} (Base: ₹{vt_data['base_fare']}, Per km: ₹{vt_data['fare_per_km']}, Capacity: {vt_data['capacity_in_kg']}kg)")
        
        try:
            response = requests.post(
                f"{base_url}/api/vehicles/types/create/",
                json=vt_data,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get('created'):
                    print(f"     ✅ Created successfully (ID: {result['vehicle_type']['id']})")
                    created_count += 1
                else:
                    print(f"     ✅ Updated successfully (ID: {result['vehicle_type']['id']})")
                    updated_count += 1
            else:
                error_msg = response.json().get('error', f'Status {response.status_code}')
                print(f"     ❌ Failed: {error_msg}")
                error_count += 1
        except Exception as e:
            print(f"     ❌ Error: {e}")
            error_count += 1
    
    print()
    print("=" * 50)
    print(f"📊 Summary: {created_count} created, {updated_count} updated, {error_count} errors")
    print()

def main():
    parser = argparse.ArgumentParser(description='Seed recharge plans and vehicle types via API')
    parser.add_argument('--base-url', default=BASE_URL, help=f'Base URL of the API (default: {BASE_URL})')
    args = parser.parse_args()
    
    base_url = args.base_url.rstrip('/')
    
    print(f"🌐 Using API endpoint: {base_url}")
    print()
    
    # Test connection
    try:
        response = requests.get(f"{base_url}/health/", timeout=5)
        if response.status_code == 200:
            print("✅ API connection successful")
        else:
            print(f"⚠️  API returned status {response.status_code}")
    except Exception as e:
        print(f"❌ Failed to connect to API: {e}")
        print(f"   Please check if the endpoint is correct: {base_url}")
        sys.exit(1)
    
    print()
    
    # Seed data
    seed_recharge_plans(base_url)
    seed_vehicle_types(base_url)
    
    print("✅ Done!")

if __name__ == '__main__':
    main()

