from rest_framework import serializers
from .models import VehicleType

class VehicleTypeSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = VehicleType
        fields = ['id', 'name', 'base_fare', 'fare_per_km', 'capacity_in_kg', 'image_url']

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and hasattr(obj.image, 'url'):
            return request.build_absolute_uri(obj.image.url)
        return None