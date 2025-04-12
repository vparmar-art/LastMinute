# users/models/customer.py

from django.db import models
from django.utils import timezone

class Customer(models.Model):
    phone_number = models.CharField(max_length=15, unique=True)
    full_name = models.CharField(max_length=100)
    password = models.CharField(max_length=128)  # If you want password-based login
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.full_name

class CustomerOTP(models.Model):
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='otps')
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_verified = models.BooleanField(default=False)
    session_id = models.CharField(max_length=64, null=True, blank=True)

    def is_expired(self):
        return timezone.now() > self.created_at + timezone.timedelta(minutes=5)

    def __str__(self):
        return f"{self.customer.phone_number} - {self.code}"