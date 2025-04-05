from django.urls import path
from .views import LoginView, SendOTPView, VerifyOTPView

urlpatterns = [
    path('login', LoginView.as_view(), name='login'),
    path('send-otp', SendOTPView.as_view()),
    path('verify-otp', VerifyOTPView.as_view())
]