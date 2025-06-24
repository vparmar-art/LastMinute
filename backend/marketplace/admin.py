from django.contrib import admin
from .models import Product, Category, Order, OrderItem, Review, Address


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('name', 'seller', 'price', 'quantity_available', 'is_active', 'created_at')
    search_fields = ('name', 'seller__display_name')
    list_filter = ('is_active', 'created_at')


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name',)
    search_fields = ('name',)


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'customer', 'status', 'total_amount', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('customer__name',)


@admin.register(OrderItem)
class OrderItemAdmin(admin.ModelAdmin):
    list_display = ('order', 'product', 'quantity', 'price')


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ('product', 'customer', 'rating', 'created_at')
    list_filter = ('rating',)


@admin.register(Address)
class AddressAdmin(admin.ModelAdmin):
    list_display = ('customer', 'city', 'state', 'country', 'is_default')
    list_filter = ('is_default', 'city', 'state')
