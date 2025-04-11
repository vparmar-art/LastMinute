from django.urls import path
from .views import VehicleTypeListView

urlpatterns = [
    path('types/', VehicleTypeListView.as_view(), name='vehicle-type-list'),
]