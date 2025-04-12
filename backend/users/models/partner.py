# users/models/partner.py

from django.db import models
from django.utils import timezone

class Partner(models.Model):
    phone_number = models.CharField(max_length=15, unique=True)
    business_name = models.CharField(max_length=100)
    license_number = models.CharField(max_length=50)
    vehicle_type = models.CharField(max_length=30)
    password = models.CharField(max_length=128)  # Optional: use for login
    is_approved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.business_name or self.phone_number

class PartnerOTP(models.Model):
    partner = models.ForeignKey(Partner, on_delete=models.CASCADE, related_name='otps')
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_verified = models.BooleanField(default=False)
    session_id = models.CharField(max_length=64, null=True, blank=True)

    def is_expired(self):
        return timezone.now() > self.created_at + timezone.timedelta(minutes=5)

    def __str__(self):
        return f"{self.partner.phone_number} - {self.code}"