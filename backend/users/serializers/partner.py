from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer
from users.models.partner import Partner

class PartnerSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = Partner
        fields = ['id', 'username', 'phone_number', 'user_type', 'owner_full_name', 'vehicle_type', 'vehicle_number', 'registration_number', 'driver_name', 'driver_license', 'license_document', 'registration_document', 'selfie', 'current_step', 'is_submitted', 'is_verified', 'is_rejected', 'rejection_reason', 'device_endpoint_arn', 'created_at', 'updated_at']
        read_only_fields = ['user_type', 'created_at', 'updated_at']

    def create(self, validated_data):
        validated_data['user_type'] = 'partner'
        return super().create(validated_data)