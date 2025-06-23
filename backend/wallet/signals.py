from django.db.models.signals import post_save
from django.dispatch import receiver
from users.models import Partner, Customer
from .models import PartnerWallet, CustomerWallet

@receiver(post_save, sender=Partner)
def create_partner_wallet(sender, instance, created, **kwargs):
    if created and not instance.wallet:
        wallet = PartnerWallet.objects.create(partner=instance)
        instance.wallet = wallet
        instance.save(update_fields=['wallet'])

@receiver(post_save, sender=Customer)
def create_customer_wallet(sender, instance, created, **kwargs):
    if created and not hasattr(instance, 'wallet'):
        CustomerWallet.objects.create(customer=instance)