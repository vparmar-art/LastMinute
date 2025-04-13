from rest_framework import serializers
from users.models.customer import Customer

class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = ['id', 'username', 'phone_number', 'user_type']
        read_only_fields = ['user_type']

    def create(self, validated_data):
        validated_data['user_type'] = 'customer'
        return super().create(validated_data)