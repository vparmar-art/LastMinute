from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User
from .models import OTP

class UserAdmin(BaseUserAdmin):
    model = User
    list_display = ['username', 'email', 'phone_number', 'user_type', 'is_staff']
    fieldsets = BaseUserAdmin.fieldsets + (
        (None, {'fields': ('phone_number', 'user_type')}),
    )
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        (None, {'fields': ('phone_number', 'user_type')}),
    )


@admin.register(OTP)
class OTPAdmin(admin.ModelAdmin):
    list_display = ('phone_number', 'code', 'created_at', 'is_verified', 'is_expired_display')
    list_filter = ('is_verified', 'created_at')
    search_fields = ('phone_number', 'code')
    readonly_fields = ('phone_number', 'code', 'created_at', 'session_id', 'is_expired_display')

    def is_expired_display(self, obj):
        return obj.is_expired()
    is_expired_display.short_description = 'Is Expired'
    is_expired_display.boolean = True

admin.site.register(User, UserAdmin)
