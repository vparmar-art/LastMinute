from django.contrib import admin
from users.models.customer import Customer, CustomerOTP
from users.models.partner import Partner, PartnerOTP
from users.models.token import Token
from users.models.seller import Seller
from django.contrib.gis.admin import GISModelAdmin

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
class PartnerAdmin(GISModelAdmin):
    list_display = (
        'id',
        'phone_number',
        'owner_full_name',
        'vehicle_type',
        'vehicle_number',
        'driver_name',
        'is_verified',
        'is_submitted',
        'is_rejected',
        'created_at',
    )
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

@admin.register(Seller)
class SellerAdmin(admin.ModelAdmin):
    list_display = ('id', 'merchant_name', 'phone_number', 'created_at')
    search_fields = ('merchant_name', 'phone_number')
    list_filter = ('created_at',)
