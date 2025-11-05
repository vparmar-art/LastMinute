from rest_framework.serializers import ModelSerializer
from .models import Booking
from vehicles.models import VehicleType
from rest_framework import serializers

class VehicleTypeField(serializers.PrimaryKeyRelatedField):
    def to_representation(self, value):
        # Handle PKOnlyObject (from DRF optimization)
        if hasattr(value, 'id') and hasattr(value, 'name'):
            return {'id': value.id, 'name': value.name}
        elif hasattr(value, 'pk'):
            obj = VehicleType.objects.filter(pk=value.pk).first()
            if obj:
                return {'id': obj.id, 'name': obj.name}
            return {'id': value.pk, 'name': None}
        return None

    def to_internal_value(self, data):
        if isinstance(data, int):
            return VehicleType.objects.get(id=data)
        elif isinstance(data, str):
            return VehicleType.objects.get(name=data)
        elif isinstance(data, dict):
            if 'id' in data:
                return VehicleType.objects.get(id=data['id'])
            elif 'name' in data:
                return VehicleType.objects.get(name=data['name'])
        raise serializers.ValidationError('Invalid vehicle_type')

class BookingSerializer(serializers.ModelSerializer):
    vehicle_type = VehicleTypeField(queryset=VehicleType.objects.all(), required=False, allow_null=True)

    class Meta:
        model = Booking
        fields = [
            'id', 'customer', 'partner', 'pickup_location', 
            'drop_location', 'pickup_latlng', 'drop_latlng',
            'pickup_time', 'drop_time', 'status', 'amount', 
            'description', 'weight', 'dimensions', 'instructions', 'distance_km',
            'created_at', 'modified_at', 'distance_km', 'pickup_otp', 'drop_otp', 'boxes','helper_required',
            'vehicle_type', 'booking_type', 'scheduled_time'
        ]

    def to_json(self):
        from rest_framework.renderers import JSONRenderer
        return JSONRenderer().render(self.data).decode('utf-8')
