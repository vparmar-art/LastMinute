from django.db import models
from users.models import Partner, Customer
from django.utils import timezone
from datetime import timedelta

class PartnerWallet(models.Model):
    partner = models.OneToOneField(Partner, on_delete=models.CASCADE, related_name="partner")
    balance = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    last_updated = models.DateTimeField(auto_now=True)
    rides_remaining = models.PositiveIntegerField(default=0)
    valid_until = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.partner.driver_name} Wallet - ₹{self.balance}"


class CustomerWallet(models.Model):
    customer = models.OneToOneField(Customer, on_delete=models.CASCADE, related_name="customer")
    balance = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    last_updated = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.customer.name} Wallet - ₹{self.balance}"


class RechargePlan(models.Model):
    name = models.CharField(max_length=100)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    ride_credits = models.PositiveIntegerField(null=True, blank=True, help_text="Used if plan_type is ride_count")
    duration_days = models.PositiveIntegerField(null=True, blank=True, help_text="Used if plan_type is duration")
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)


class WalletTransaction(models.Model):
    TRANSACTION_TYPES = [
        ('credit', 'Credit'),
        ('debit', 'Debit'),
    ]

    partner_wallet = models.ForeignKey(
        PartnerWallet,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='partner_transactions'
    )
    customer_wallet = models.ForeignKey(
        CustomerWallet,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='customer_transactions'
    )
    transaction_type = models.CharField(max_length=10, choices=TRANSACTION_TYPES)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    plan = models.ForeignKey('wallet.RechargePlan', on_delete=models.SET_NULL, null=True, blank=True)
    booking = models.ForeignKey('bookings.Booking', on_delete=models.SET_NULL, null=True, blank=True)
    description = models.TextField(blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        if self.partner_wallet:
            name = self.partner_wallet.partner.driver_name
        elif self.customer_wallet:
            name = self.customer_wallet.customer.name
        else:
            name = "Unknown"
        plan_name = f" via {self.plan.name}" if self.plan else ""
        return f"{name} - {self.transaction_type} ₹{self.amount}{plan_name}"
