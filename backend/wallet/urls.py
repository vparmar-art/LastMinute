from django.urls import path
from . import views

urlpatterns = [
    path('plans/', views.list_recharge_plans, name='list_recharge_plans'),
    path('partner-wallet/<int:partner_id>/', views.get_partner_wallet, name='get_partner_wallet'),
]