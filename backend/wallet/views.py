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
from django.views.decorators.http import require_http_methods

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

@csrf_exempt
@require_http_methods(["POST"])
def create_recharge_plan(request):
    """Create a recharge plan via API"""
    try:
        data = json.loads(request.body)
        
        # Validate required fields
        required_fields = ['name', 'amount']
        for field in required_fields:
            if field not in data:
                return JsonResponse({'error': f'Missing required field: {field}'}, status=400)
        
        # Create or update the plan
        plan, created = RechargePlan.objects.get_or_create(
            name=data['name'],
            defaults={
                'amount': float(data['amount']),
                'ride_credits': data.get('ride_credits'),
                'duration_days': data.get('duration_days'),
                'description': data.get('description', ''),
                'is_active': data.get('is_active', True)
            }
        )
        
        if not created:
            # Update existing plan
            plan.amount = float(data['amount'])
            if 'ride_credits' in data:
                plan.ride_credits = data['ride_credits']
            if 'duration_days' in data:
                plan.duration_days = data['duration_days']
            if 'description' in data:
                plan.description = data['description']
            if 'is_active' in data:
                plan.is_active = data['is_active']
            plan.save()
        
        return JsonResponse({
            'success': True,
            'created': created,
            'plan': {
                'id': plan.id,
                'name': plan.name,
                'amount': str(plan.amount),
                'ride_credits': plan.ride_credits,
                'duration_days': plan.duration_days,
                'description': plan.description,
                'is_active': plan.is_active
            }
        })
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
