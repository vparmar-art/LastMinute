from django.urls import path
from users.views.partner import PartnerSendOTPView, PartnerVerifyOTPView

urlpatterns = [
    path('send-otp/', PartnerSendOTPView.as_view(), name='partner-send-otp'),
    path('verify-otp/', PartnerVerifyOTPView.as_view(), name='partner-verify-otp'),
]