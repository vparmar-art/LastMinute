from rest_framework import serializers
from users.models.partner import Partner
from users.models.partner import PartnerVerification

class PartnerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Partner
        fields = ['id', 'username', 'phone_number', 'user_type']
        read_only_fields = ['user_type']

    def create(self, validated_data):
        validated_data['user_type'] = 'partner'
        return super().create(validated_data)

class PartnerVerificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = PartnerVerification
        fields = ['partner', 'owner_full_name', 'vehicle_type', 'vehicle_number', 'registration_number', 
                  'driver_name', 'driver_license', 'license_document', 'registration_document', 'selfie', 
                  'current_step', 'is_submitted', 'is_verified', 'is_rejected', 'rejection_reason', 'created_at', 'updated_at']
        read_only_fields = ['partner', 'created_at', 'updated_at']