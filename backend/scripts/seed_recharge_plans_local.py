#!/usr/bin/env python
"""
Script to seed RechargePlan objects in the local database
Usage: python scripts/seed_recharge_plans_local.py
"""

import os
import sys
import django

# Add the backend directory to the path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Set up Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'main.settings')
django.setup()

from wallet.models import RechargePlan

def seed_recharge_plans():
    """Seed recharge plans in the database"""
    
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
            'ride_credits': None,  # Unlimited
            'duration_days': 30,
            'description': 'Unlimited rides for 30 days',
            'is_active': True
        },
    ]
    
    created_count = 0
    updated_count = 0
    
    print("💳 Seeding Recharge Plans")
    print("=" * 50)
    print()
    
    for plan_data in plans:
        plan, created = RechargePlan.objects.get_or_create(
            name=plan_data['name'],
            defaults={
                'amount': plan_data['amount'],
                'ride_credits': plan_data['ride_credits'],
                'duration_days': plan_data['duration_days'],
                'description': plan_data['description'],
                'is_active': plan_data['is_active']
            }
        )
        
        if created:
            rides = f"{plan.ride_credits} rides" if plan.ride_credits else "Unlimited rides"
            print(f"✅ Created: {plan.name} - ₹{plan.amount} ({rides}, {plan.duration_days} days)")
            created_count += 1
        else:
            # Update existing if needed
            updated = False
            if plan.amount != plan_data['amount']:
                plan.amount = plan_data['amount']
                updated = True
            if plan.ride_credits != plan_data['ride_credits']:
                plan.ride_credits = plan_data['ride_credits']
                updated = True
            if plan.duration_days != plan_data['duration_days']:
                plan.duration_days = plan_data['duration_days']
                updated = True
            if plan.description != plan_data['description']:
                plan.description = plan_data['description']
                updated = True
            if plan.is_active != plan_data['is_active']:
                plan.is_active = plan_data['is_active']
                updated = True
            
            if updated:
                plan.save()
                rides = f"{plan.ride_credits} rides" if plan.ride_credits else "Unlimited rides"
                print(f"🔄 Updated: {plan.name} - ₹{plan.amount} ({rides}, {plan.duration_days} days)")
                updated_count += 1
            else:
                rides = f"{plan.ride_credits} rides" if plan.ride_credits else "Unlimited rides"
                print(f"✓ Already exists: {plan.name} - ₹{plan.amount} ({rides}, {plan.duration_days} days)")
    
    print()
    print("=" * 50)
    print(f"📊 Summary: Created {created_count}, Updated {updated_count}")
    print()
    
    # List all active plans
    print("📋 All Active Recharge Plans:")
    all_plans = RechargePlan.objects.filter(is_active=True).order_by('amount')
    for plan in all_plans:
        rides = f"{plan.ride_credits} rides" if plan.ride_credits else "Unlimited rides"
        status = "Active" if plan.is_active else "Inactive"
        print(f"  - {plan.name}: ₹{plan.amount} ({rides}, {plan.duration_days} days) [{status}]")

if __name__ == '__main__':
    seed_recharge_plans()

