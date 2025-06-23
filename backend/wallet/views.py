from django.shortcuts import render
from django.http import JsonResponse
from django.forms.models import model_to_dict
from users.models import Partner
from .models import RechargePlan, PartnerWallet


def list_recharge_plans(request):
    plans = RechargePlan.objects.filter(is_active=True).values()
    return JsonResponse(list(plans), safe=False)


def get_partner_wallet(request, partner_id):
    try:
        partner = Partner.objects.get(id=partner_id)
        wallet = PartnerWallet.objects.get(partner=partner)
        return JsonResponse(model_to_dict(wallet))
    except (Partner.DoesNotExist, PartnerWallet.DoesNotExist):
        return JsonResponse({"error": "Wallet not found for the given partner ID."}, status=404)
