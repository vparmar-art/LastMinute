from django.urls import path, include

urlpatterns = [
    path('customer/', include('users.urls.customer_urls')),
    path('partner/', include('users.urls.partner_urls')),
]