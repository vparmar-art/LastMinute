from django.urls import path
from users.views.customer import CustomerSendOTPView, CustomerVerifyOTPView

urlpatterns = [
    path('send-otp/', CustomerSendOTPView.as_view(), name='customer-send-otp'),
    path('verify-otp/', CustomerVerifyOTPView.as_view(), name='customer-verify-otp'),
]