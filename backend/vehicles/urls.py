from django.urls import path
from .views import VehicleTypeListView, create_vehicle_type

urlpatterns = [
    path('types/', VehicleTypeListView.as_view(), name='vehicle-type-list'),
    path('types/create/', create_vehicle_type, name='create-vehicle-type'),
]