from django.urls import path
from . import views

urlpatterns = [
    path('list/', views.booking_list, name='booking_list'),  # To list and create bookings
    path('<int:pk>/', views.booking_detail, name='booking_detail'),  # To view or update a specific booking
    path('<int:pk>/status/', views.update_booking_status, name='update_booking_status'),  # To update the status of a booking
]