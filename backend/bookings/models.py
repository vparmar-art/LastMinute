from django.db import models
from users.models import Partner, Customer
from django.utils import timezone

# Create your models here.

class Booking(models.Model):
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='bookings')
    partner = models.ForeignKey(Partner, on_delete=models.CASCADE, related_name='bookings')
    pickup_location = models.CharField(max_length=255)
    drop_location = models.CharField(max_length=255)
    pickup_time = models.DateTimeField()
    drop_time = models.DateTimeField()
    status = models.CharField(
        max_length=20,
        choices=[
            ('created', 'Created'),
            ('in_transit', 'In Transit'),
            ('arriving', 'Arriving'),
            ('completed', 'Completed'),
            ('cancelled', 'Cancelled')
        ],
        default='created'
    )
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)
    modified_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Booking {self.id} - {self.customer.phone_number} -> {self.partner.phone_number}"

    class Meta:
        ordering = ['-created_at']