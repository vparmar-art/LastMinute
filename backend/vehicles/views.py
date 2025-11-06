from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.http import JsonResponse
from .models import VehicleType
from .serializers import VehicleTypeSerializer
import json

class VehicleTypeListView(APIView):
    permission_classes = [AllowAny]
    
    def get(self, request):
        vehicles = VehicleType.objects.filter(is_active=True)
        serializer = VehicleTypeSerializer(vehicles, many=True, context={'request': request})
        return Response(serializer.data)

@csrf_exempt
def create_vehicle_type(request):
    """Create a vehicle type via API"""
    if request.method != 'POST':
        return JsonResponse({'error': 'Only POST requests allowed'}, status=405)
    
    try:
        data = json.loads(request.body)
        
        # Validate required fields
        required_fields = ['name', 'base_fare', 'fare_per_km', 'capacity_in_kg']
        for field in required_fields:
            if field not in data:
                return JsonResponse({'error': f'Missing required field: {field}'}, status=400)
        
        # Create or update the vehicle type
        vehicle_type, created = VehicleType.objects.get_or_create(
            name=data['name'],
            defaults={
                'base_fare': float(data['base_fare']),
                'fare_per_km': float(data['fare_per_km']),
                'capacity_in_kg': int(data['capacity_in_kg']),
                'is_active': data.get('is_active', True)
            }
        )
        
        if not created:
            # Update existing vehicle type
            vehicle_type.base_fare = float(data['base_fare'])
            vehicle_type.fare_per_km = float(data['fare_per_km'])
            vehicle_type.capacity_in_kg = int(data['capacity_in_kg'])
            if 'is_active' in data:
                vehicle_type.is_active = data['is_active']
            vehicle_type.save()
        
        return JsonResponse({
            'success': True,
            'created': created,
            'vehicle_type': {
                'id': vehicle_type.id,
                'name': vehicle_type.name,
                'base_fare': str(vehicle_type.base_fare),
                'fare_per_km': str(vehicle_type.fare_per_km),
                'capacity_in_kg': vehicle_type.capacity_in_kg,
                'is_active': vehicle_type.is_active
            }
        })
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)