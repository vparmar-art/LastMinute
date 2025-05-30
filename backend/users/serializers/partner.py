from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer
from users.models.partner import Partner

class PartnerSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = Partner
        geo_field = 'current_location'  
        fields = [
            'id', 'phone_number', 'password', 'owner_full_name',
            'vehicle_type', 'vehicle_number', 'registration_number', 'driver_name',
            'driver_license', 'driver_phone', 'license_document', 'registration_document',
            'selfie', 'current_step', 'is_submitted', 'is_verified', 'is_rejected',
            'rejection_reason', 'device_endpoint_arn', 'created_at', 'updated_at',
            'is_live', 'current_location'
        ]
        read_only_fields = ['created_at', 'updated_at']