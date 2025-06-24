

from django.urls import path
from . import views

urlpatterns = [
    path('categories/', views.list_categories, name='list_categories'),
    path('products/', views.list_products, name='list_products'),
    path('products/<int:product_id>/', views.product_detail, name='product_detail'),
    path('orders/', views.place_order, name='place_order'),
    path('orders/customer/<int:customer_id>/', views.customer_orders, name='customer_orders'),
]