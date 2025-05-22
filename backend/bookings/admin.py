from django.contrib import admin
from .models import Booking
from django.contrib.gis.admin import GISModelAdmin

# Register your models here.
@admin.register(Booking)
class BookingAdmin(GISModelAdmin):
    list_display = ('id', 'customer', 'status', 'pickup_location', 'drop_location', 'created_at', 'modified_at')
    list_filter = ('status', 'created_at')
    search_fields = ('customer__id', 'pickup_location', 'drop_location')
