from django.db import models
from django.contrib.gis.db import models as gis_models
from users.models import Partner, Customer
from django.utils import timezone

# Create your models here.

class Booking(models.Model):
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='bookings')
    partner = models.ForeignKey(Partner, on_delete=models.SET_NULL, null=True, blank=True)
    pickup_location = models.CharField(max_length=255)
    pickup_latlng = gis_models.PointField(geography=True, blank=True, null=True)
    drop_location = models.CharField(max_length=255)
    drop_latlng = gis_models.PointField(geography=True, blank=True, null=True)
    pickup_time = models.DateTimeField()
    drop_time = models.DateTimeField()
    description = models.TextField(blank=True, null=True)
    weight = models.CharField(max_length=50, blank=True, null=True)
    dimensions = models.CharField(max_length=100, blank=True, null=True)
    boxes = models.IntegerField(blank=True, null=True)
    helper_required = models.BooleanField(default=False)
    instructions = models.TextField(blank=True, null=True)
    distance_km = models.FloatField(blank=True, null=True)
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
    pickup_otp = models.CharField(max_length=4, blank=True, null=True)
    drop_otp = models.CharField(max_length=4, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    modified_at = models.DateTimeField(auto_now=True)
    
    # Enhanced ride experience fields
    rating = models.IntegerField(blank=True, null=True, choices=[
        (1, '1 Star'),
        (2, '2 Stars'),
        (3, '3 Stars'),
        (4, '4 Stars'),
        (5, '5 Stars'),
    ])
    review = models.TextField(blank=True, null=True)
    ride_rating_submitted = models.BooleanField(default=False)
    eta_minutes = models.IntegerField(blank=True, null=True)
    actual_duration_minutes = models.IntegerField(blank=True, null=True)
    emergency_contacted = models.BooleanField(default=False)
    customer_feedback = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"Booking {self.id}"

    class Meta:
        ordering = ['-created_at']
        
    @property
    def is_completed(self):
        return self.status == 'completed'
        
    @property
    def is_in_progress(self):
        return self.status in ['arriving', 'in_transit']
        
    @property
    def can_be_rated(self):
        return self.is_completed and not self.ride_rating_submitted