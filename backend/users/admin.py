from django.contrib import admin
from users.models.customer import Customer, CustomerOTP
from users.models.partner import Partner, PartnerOTP, PartnerVerification
from users.models.token import Token

@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ('id', 'full_name', 'phone_number', 'is_verified', 'created_at')
    search_fields = ('full_name', 'phone_number')
    list_filter = ('is_verified', 'created_at')


@admin.register(CustomerOTP)
class CustomerOTPAdmin(admin.ModelAdmin):
    list_display = ('id', 'customer', 'code', 'is_verified', 'created_at')
    search_fields = ('customer__phone_number', 'code')
    list_filter = ('is_verified', 'created_at')


@admin.register(Partner)
class PartnerAdmin(admin.ModelAdmin):
    list_display = ('id', 'phone_number', 'created_at')  # Removed unnecessary fields
    search_fields = ('phone_number',)
    list_filter = ('created_at',)


@admin.register(PartnerOTP)
class PartnerOTPAdmin(admin.ModelAdmin):
    list_display = ('id', 'partner', 'code', 'is_verified', 'created_at')
    search_fields = ('partner__phone_number', 'code')
    list_filter = ('is_verified', 'created_at')

@admin.register(Token)
class TokenAdmin(admin.ModelAdmin):
    list_display = ('customer', 'partner', 'key', 'created_at')  # Display the relevant fields
    search_fields = ('customer__phone_number', 'partner__phone_number', 'key')  # Enable search for phone numbers and token key
    list_filter = ('created_at',)  # Allow filtering by creation date

@admin.register(PartnerVerification)
class PartnerVerificationAdmin(admin.ModelAdmin):
    list_display = ('id', 'partner', 'owner_full_name', 'vehicle_type', 'vehicle_number', 'registration_number', 'created_at', 'updated_at')  # Removed unnecessary fields
    search_fields = ('partner__phone_number', 'owner_full_name', 'vehicle_number', 'registration_number')
    list_filter = ('created_at',)