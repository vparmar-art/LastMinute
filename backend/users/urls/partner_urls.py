from django.urls import path
from users.views.partner import PartnerSendOTPView, PartnerVerifyOTPView, PartnerProfileView, PartnerVerificationView

urlpatterns = [
    path('send-otp/', PartnerSendOTPView.as_view(), name='partner-send-otp'),
    path('verify-otp/', PartnerVerifyOTPView.as_view(), name='partner-verify-otp'),
    path('profile/', PartnerProfileView.as_view(), name='partner-profile'),
    path('verification/', PartnerVerificationView.as_view(), name='partner-verification'),
]