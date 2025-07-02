from django.urls import path
from . import views

urlpatterns = [
    path('list/', views.booking_list, name='booking_list'),  # To list and create bookings
    path('<int:booking_id>/', views.booking_detail, name='booking_detail'),  # To view or update a specific booking
    path('<int:booking_id>/status/', views.update_booking_status, name='update_booking_status'),  # To update the status of a booking
    path('start/', views.start_booking, name='start_booking'),
    path('validate-pickup-otp/', views.validate_pickup_otp, name='validate_pickup_otp'),
    path('validate-drop-otp/', views.validate_drop_otp, name='validate_drop_otp'),
    path('full-details/<int:booking_id>/', views.booking_full_details, name='booking_full_details'),
]