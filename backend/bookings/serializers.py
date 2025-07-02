from rest_framework.serializers import ModelSerializer
from .models import Booking

class BookingSerializer(ModelSerializer):
    class Meta:
        model = Booking
        fields = ['id', 'customer', 'partner', 'pickup_location', 
                  'drop_location', 'pickup_latlng', 'drop_latlng',
                  'pickup_time', 'drop_time', 'status', 'amount', 
                  'description', 'weight', 'dimensions', 'instructions', 'distance_km',
                  'created_at', 'modified_at', 'distance_km', 'pickup_otp', 'drop_otp', 'boxes','helper_required'
                ]

    def to_json(self):
        from rest_framework.renderers import JSONRenderer
        return JSONRenderer().render(self.data).decode('utf-8')
