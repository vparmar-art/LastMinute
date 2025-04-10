from django.db import models

class VehicleType(models.Model):
    VEHICLE_CHOICES = [
        ('bike', 'Bike'),
        ('auto', 'Auto'),
        ('mini_truck', 'Mini Truck'),
        ('truck', 'Truck'),
    ]

    name = models.CharField(max_length=20, choices=VEHICLE_CHOICES, unique=True)
    base_fare = models.DecimalField(max_digits=6, decimal_places=2, help_text="Base fare for this vehicle")
    fare_per_km = models.DecimalField(max_digits=6, decimal_places=2, help_text="Fare per km")
    capacity_in_kg = models.PositiveIntegerField(help_text="Maximum load capacity in KG")
    image = models.ImageField(upload_to='vehicle_images/', null=True, blank=True)

    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.get_name_display()

    class Meta:
        verbose_name = "Vehicle Type"
        verbose_name_plural = "Vehicle Types"