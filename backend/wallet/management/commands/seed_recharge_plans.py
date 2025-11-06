from django.core.management.base import BaseCommand
from wallet.models import RechargePlan


class Command(BaseCommand):
    help = 'Seed recharge plans in the database'

    def handle(self, *args, **options):
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
        
        created_count = 0
        updated_count = 0
        
        self.stdout.write(self.style.SUCCESS('💳 Seeding Recharge Plans'))
        self.stdout.write('=' * 50)
        
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
                self.stdout.write(self.style.SUCCESS(f'✅ Created: {plan.name} - ₹{plan.amount} ({rides}, {plan.duration_days} days)'))
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
                    self.stdout.write(self.style.WARNING(f'🔄 Updated: {plan.name} - ₹{plan.amount} ({rides}, {plan.duration_days} days)'))
                    updated_count += 1
                else:
                    rides = f"{plan.ride_credits} rides" if plan.ride_credits else "Unlimited rides"
                    self.stdout.write(f'✓ Already exists: {plan.name} - ₹{plan.amount} ({rides}, {plan.duration_days} days)')
        
        self.stdout.write('=' * 50)
        self.stdout.write(self.style.SUCCESS(f'📊 Summary: Created {created_count}, Updated {updated_count}'))

