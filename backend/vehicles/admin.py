from django.contrib import admin
from .models import VehicleType

@admin.register(VehicleType)
class VehicleTypeAdmin(admin.ModelAdmin):
    list_display = ('name', 'base_fare', 'fare_per_km', 'capacity_in_kg', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name',)