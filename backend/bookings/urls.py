from django.urls import path
from . import views

urlpatterns = [
    path('', views.booking_list, name='booking-list'),
    path('<int:booking_id>/', views.booking_detail, name='booking-detail'),
    path('<int:booking_id>/status/', views.update_booking_status, name='update-booking-status'),
    path('start/', views.start_booking, name='start-booking'),
    path('validate-pickup-otp/', views.validate_pickup_otp, name='validate-pickup-otp'),
    path('validate-drop-otp/', views.validate_drop_otp, name='validate-drop-otp'),
    path('<int:booking_id>/full-details/', views.booking_full_details, name='booking-full-details'),
    path('<int:booking_id>/rate/', views.submit_ride_rating, name='submit-ride-rating'),
    path('<int:booking_id>/emergency/', views.report_emergency, name='report-emergency'),
]