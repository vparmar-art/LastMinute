from django.db import models
from django.contrib.auth.models import User

class Seller(models.Model):
    merchant_name = models.CharField(max_length=255)
    email = models.EmailField(max_length=254, unique=True)
    phone_number = models.CharField(max_length=20, blank=True)
    address = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.merchant_name