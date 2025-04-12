from django.db import models
from django.utils import timezone
from users.models.customer import Customer
from users.models.partner import Partner

class Token(models.Model):
    customer = models.OneToOneField(Customer, on_delete=models.CASCADE, null=True, blank=True)
    partner = models.OneToOneField(Partner, on_delete=models.CASCADE, null=True, blank=True)
    key = models.CharField(max_length=255, unique=True)  # Store token here
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Token for {'customer' if self.customer else 'partner'}: {self.key}"

    def is_expired(self):
        # Set a token expiration period (e.g., 24 hours)
        return self.created_at + timezone.timedelta(hours=24) < timezone.now()