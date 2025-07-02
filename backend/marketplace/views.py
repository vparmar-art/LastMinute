from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.forms.models import model_to_dict
from marketplace.models import Product, Category, Order, OrderItem
from users.models.seller import Seller
from users.models.customer import Customer
import json

def list_categories(request):
    categories = Category.objects.all()
    data = [model_to_dict(category) for category in categories]
    return JsonResponse(data, safe=False)

def list_products(request):
    products = Product.objects.filter(is_active=True)
    data = []
    print("api called")
    for product in products:
        item = {
            'id': product.id,
            'name': product.name,
            'description': product.description,
            'price': str(product.price),
            'quantity_available': product.quantity_available,
            'image': product.image.url if product.image else None,
            'seller': product.seller.merchant_name,
            'category': product.category.name if product.category else None,
            'is_active': product.is_active,
            'created_at': product.created_at,
        }
        data.append(item)
    return JsonResponse(data, safe=False)

def product_detail(request, product_id):
    try:
        product = Product.objects.get(pk=product_id)
        data = {
            'id': product.id,
            'name': product.name,
            'description': product.description,
            'price': str(product.price),
            'quantity_available': product.quantity_available,
            'image': product.image.url if product.image else None,
            'seller': product.seller.merchant_name,
            'category': product.category.name if product.category else None,
            'is_active': product.is_active,
            'created_at': product.created_at,
        }
        return JsonResponse(data)
    except Product.DoesNotExist:
        return JsonResponse({'error': 'Product not found'}, status=404)

@csrf_exempt
@require_http_methods(["POST"])
def place_order(request):
    try:
        body = json.loads(request.body)
        customer_id = body.get('customer_id')
        items = body.get('items')  # List of {product_id, quantity}

        customer = Customer.objects.get(pk=customer_id)

        total = 0
        order = Order.objects.create(customer=customer, total_amount=0)

        for item in items:
            product = Product.objects.get(pk=item['product_id'])
            quantity = item['quantity']
            if product.quantity_available < quantity:
                return JsonResponse({'error': f'Not enough stock for {product.name}'}, status=400)
            price = product.price * quantity
            OrderItem.objects.create(order=order, product=product, quantity=quantity, price=price)
            total += price
            product.quantity_available -= quantity
            product.save()

        order.total_amount = total
        order.save()

        return JsonResponse({'success': True, 'order_id': order.id})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

def customer_orders(request, customer_id):
    try:
        customer = Customer.objects.get(pk=customer_id)
        orders = customer.orders.all()
        result = []
        for order in orders:
            items = [{
                'product': item.product.name,
                'quantity': item.quantity,
                'price': float(item.price)
            } for item in order.items.all()]
            result.append({
                'id': order.id,
                'status': order.status,
                'total': float(order.total_amount),
                'items': items,
                'created_at': order.created_at,
            })
        return JsonResponse(result, safe=False)
    except Customer.DoesNotExist:
        return JsonResponse({'error': 'Customer not found'}, status=404)


# Cart API views
@csrf_exempt
@require_http_methods(["GET"])
def get_cart(request, customer_id):
    try:
        customer = Customer.objects.get(pk=customer_id)
        cart = customer.cart
        items = [{
            'product_id': item.product.id,
            'product': item.product.name,
            'quantity': item.quantity,
            'price': float(item.price)
        } for item in cart.order.items.all()]
        return JsonResponse({'cart_id': cart.id, 'items': items})
    except Customer.DoesNotExist:
        return JsonResponse({'error': 'Customer not found'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
def update_cart_item(request):
    try:
        data = json.loads(request.body)
        customer_id = data.get('customer_id')
        product_id = data.get('product_id')
        quantity = data.get('quantity', 1)

        customer = Customer.objects.get(pk=customer_id)
        product = Product.objects.get(pk=product_id)

        cart, _ = customer.cart, customer.cart.order
        if not cart:
            order = Order.objects.create(customer=customer, status='cart', total_amount=0)
            cart = Cart.objects.create(customer=customer, order=order)

        order = cart.order
        item, created = OrderItem.objects.get_or_create(order=order, product=product, defaults={'quantity': quantity, 'price': product.price * quantity})

        if not created:
            item.quantity = quantity
            item.price = product.price * quantity
            item.save()

        order.total_amount = sum(i.price for i in order.items.all())
        order.save()

        return JsonResponse({'success': True})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["DELETE"])
def delete_cart_item(request):
    try:
        data = json.loads(request.body)
        customer_id = data.get('customer_id')
        product_id = data.get('product_id')

        customer = Customer.objects.get(pk=customer_id)
        cart = customer.cart
        item = OrderItem.objects.get(order=cart.order, product__id=product_id)
        item.delete()

        cart.order.total_amount = sum(i.price for i in cart.order.items.all())
        cart.order.save()

        return JsonResponse({'success': True})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)