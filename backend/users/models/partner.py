from django.db import models
from django.utils import timezone
from vehicles.models import VehicleType

class Partner(models.Model):
    phone_number = models.CharField(max_length=15, unique=True)
    password = models.CharField(max_length=128)  # Optional: use for login
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.phone_number

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

class PartnerVerification(models.Model):
    partner = models.OneToOneField('Partner', on_delete=models.CASCADE, related_name='verification')
    owner_full_name = models.CharField(max_length=100, blank=True)
    vehicle_type = models.CharField(max_length=50, choices=VehicleType.VEHICLE_CHOICES, null=True, blank=True, default=None)
    vehicle_number = models.CharField(max_length=50, blank=True)
    registration_number = models.CharField(max_length=50, blank=True)
    driver_name = models.CharField(max_length=100, blank=True)
    driver_license = models.CharField(max_length=50, blank=True)
    driver_phone = models.CharField(max_length=20, blank=True)

    # Documents
    license_document = models.FileField(upload_to='documents/licenses/', null=True, blank=True)
    registration_document = models.FileField(upload_to='documents/registration/', null=True, blank=True)
    selfie = models.ImageField(upload_to='documents/selfies/', null=True, blank=True)

    # Progress tracking
    current_step = models.PositiveIntegerField(default=1)
    is_submitted = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    is_rejected = models.BooleanField(default=False)
    rejection_reason = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

from django.db.models.signals import post_save
from django.dispatch import receiver

# Signal to create a PartnerVerification record when a Partner is created
@receiver(post_save, sender=Partner)
def create_partner_verification(sender, instance, created, **kwargs):
    if created:
        from users.models.partner import PartnerVerification  # Local import inside the signal
        # Create a PartnerVerification instance linked to the newly created Partner
        PartnerVerification.objects.create(partner=instance)