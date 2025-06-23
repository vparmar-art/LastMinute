from django.shortcuts import render
from django.http import JsonResponse
from django.forms.models import model_to_dict
from users.models import Partner
from .models import RechargePlan, PartnerWallet
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
import json
from .models import WalletTransaction
from datetime import timedelta

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

@csrf_exempt
def recharge_partner_wallet(request):
    if request.method != 'POST':
        return JsonResponse({'error': 'Only POST requests allowed'}, status=405)

    try:
        data = json.loads(request.body)
        partner_id = data.get('partner_id')
        plan_id = data.get('plan_id')

        if not partner_id or not plan_id:
            return JsonResponse({'error': 'Missing partner_id or plan_id'}, status=400)

        partner = Partner.objects.get(id=partner_id)
        wallet = partner.wallet
        plan = RechargePlan.objects.get(id=plan_id)

        if plan.ride_credits:
            wallet.rides_remaining += plan.ride_credits
        if plan.duration_days:
            wallet.valid_until = max(wallet.valid_until or timezone.now(), timezone.now()) + timedelta(days=plan.duration_days)

        wallet.save()

        WalletTransaction.objects.create(
            partner_wallet=wallet,
            transaction_type='credit',
            amount=plan.amount,
            plan=plan,
            description=f'Recharge via {plan.name}'
        )

        return JsonResponse({'success': True, 'wallet': model_to_dict(wallet)})

    except Partner.DoesNotExist:
        return JsonResponse({'error': 'Partner not found'}, status=404)
    except RechargePlan.DoesNotExist:
        return JsonResponse({'error': 'Recharge plan not found'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
