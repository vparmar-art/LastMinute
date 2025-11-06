from django.core.management.base import BaseCommand
from vehicles.models import VehicleType


class Command(BaseCommand):
    help = 'Seed vehicle types in the database'

    def handle(self, *args, **options):
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
        
        self.stdout.write(self.style.SUCCESS('🚗 Seeding Vehicle Types'))
        self.stdout.write('=' * 50)
        
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
                self.stdout.write(self.style.SUCCESS(
                    f'✅ Created: {vehicle_type.name} (Base: ₹{vehicle_type.base_fare}, '
                    f'Per km: ₹{vehicle_type.fare_per_km}, Capacity: {vehicle_type.capacity_in_kg}kg)'
                ))
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
                    self.stdout.write(self.style.WARNING(
                        f'🔄 Updated: {vehicle_type.name} (Base: ₹{vehicle_type.base_fare}, '
                        f'Per km: ₹{vehicle_type.fare_per_km}, Capacity: {vehicle_type.capacity_in_kg}kg)'
                    ))
                    updated_count += 1
                else:
                    self.stdout.write(
                        f'✓ Already exists: {vehicle_type.name} (Base: ₹{vehicle_type.base_fare}, '
                        f'Per km: ₹{vehicle_type.fare_per_km}, Capacity: {vehicle_type.capacity_in_kg}kg)'
                    )
        
        self.stdout.write('=' * 50)
        self.stdout.write(self.style.SUCCESS(f'📊 Summary: Created {created_count}, Updated {updated_count}'))

