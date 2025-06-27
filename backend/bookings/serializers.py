from rest_framework_gis.serializers import GeoFeatureModelSerializer
from .models import Booking

class BookingSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = Booking
        geo_field = 'pickup_latlng'  # Primary geographic field
        fields = [
            'id',
            'customer',
            'partner',
            'pickup_address',
            'pickup_latlng',
            'drop_address',
            'drop_latlng',
            'vehicle_type',
            'package_details',
            'estimated_distance_km',
            'total_fare',
            'status',
            'pickup_time',
            'drop_time',
            'created_at',
            'updated_at',
            'description',
            'weight',
            'dimensions',
            'instructions',
            'distance_km',
            'pickup_otp',
            'drop_otp',
            'boxes',
            'helper_required',
            'pickup_location',
            'drop_location',
            'amount',
            'modified_at'
        ]
