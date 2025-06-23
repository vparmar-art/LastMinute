
from django.contrib import admin
from .models import RechargePlan, PartnerWallet, CustomerWallet, WalletTransaction


@admin.register(RechargePlan)
class RechargePlanAdmin(admin.ModelAdmin):
    list_display = ['name', 'amount', 'is_active']
    list_filter = ['is_active']
    search_fields = ['name']


@admin.register(PartnerWallet)
class PartnerWalletAdmin(admin.ModelAdmin):
    list_display = ['partner', 'balance', 'rides_remaining', 'valid_until', 'last_updated']
    search_fields = ['partner__driver_name']


@admin.register(CustomerWallet)
class CustomerWalletAdmin(admin.ModelAdmin):
    list_display = ['customer', 'balance', 'last_updated']
    search_fields = ['customer__name']


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = ['transaction_type', 'amount', 'plan', 'timestamp']
    list_filter = ['transaction_type', 'timestamp']
    search_fields = ['partner_wallet__partner__driver_name', 'customer_wallet__customer__name']

