import json
from django.contrib.gis.geos import Point
from django.contrib.gis.db.models.functions import Distance
from rest_framework import status, serializers
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Booking
from users.models import Customer, Partner
from .serializers import BookingSerializer
from .sns import send_push_notification
from users.models.token import Token
import random

@api_view(['GET', 'POST'])
def booking_list(request):
    """
    List all bookings or create a new booking.
    """
    if request.method == 'GET':
        customer_id = request.query_params.get('customer')
        partner_id = request.query_params.get('partner')

        bookings = Booking.objects.all()
        if customer_id:
            bookings = bookings.filter(customer__id=customer_id)
        if partner_id:
            bookings = bookings.filter(partner__id=partner_id)

        serializer = BookingSerializer(bookings, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        # Ensure customer and partner exist
        customer = Customer.objects.get(id=request.data['customer'])
        partner = Partner.objects.get(id=request.data['partner'])

        booking = Booking(
            customer=customer,
            partner=partner,
            pickup_location=request.data['pickup_location'],
            drop_location=request.data['drop_location'],
            pickup_time=request.data['pickup_time'],
            drop_time=request.data['drop_time'],
            amount=request.data['amount'],
            status='created'  # Default to created
        )
        booking.description = request.data.get('description')
        booking.weight = request.data.get('weight')
        booking.dimensions = request.data.get('dimensions')
        booking.instructions = request.data.get('instructions')
        booking.distance_km = request.data.get('distance_km')
        booking.boxes = request.data.get('boxes')
        booking.helper_required = request.data.get('helper_required', False)
        booking.save()
        return Response(BookingSerializer(booking).data, status=status.HTTP_201_CREATED)

@api_view(['GET', 'PUT'])
def booking_detail(request, pk):
    """
    Retrieve or update a booking instance.
    """
    try:
        booking = Booking.objects.get(pk=pk)
    except Booking.DoesNotExist:
        return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = BookingSerializer(booking)
        return Response(serializer.data)

    elif request.method == 'PUT':
        serializer = BookingSerializer(booking, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
def update_booking_status(request, pk):
    """
    Update the status of a booking (e.g., in_transit, arriving, completed).
    Requires Authorization token for identifying the partner.
    """
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Token '):
        return Response({'error': 'Authorization token required'}, status=status.HTTP_401_UNAUTHORIZED)

    token_key = auth_header.split(' ')[1]
    try:
        token = Token.objects.get(key=token_key)
    except Token.DoesNotExist:
        return Response({'error': 'Invalid token'}, status=status.HTTP_401_UNAUTHORIZED)

    try:
        partner = token.partner
    except AttributeError:
        partner = None

    try:
        customer = token.customer
    except AttributeError:
        customer = None

    try:
        booking = Booking.objects.get(pk=pk)
    except Booking.DoesNotExist:
        return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)

    if partner:
        booking.partner = partner
    if customer:
        booking.customer = customer

    if 'status' in request.data:
        booking.status = request.data['status']

    booking.save()
    return Response(BookingSerializer(booking).data, status=status.HTTP_200_OK)


# View to start a booking and send push notifications to all partners
@api_view(['POST'])
def start_booking(request):
    """
    Create a new booking and send a push notification to all partners.
    """
    try:
        customer = Customer.objects.get(id=request.data['customer'])
    except Customer.DoesNotExist:
        return Response({'error': 'Customer not found'}, status=status.HTTP_404_NOT_FOUND)

    # Create booking with status 'created'
    booking = Booking(
        customer=customer,
        pickup_location=request.data['pickup_address'],
        drop_location=request.data['drop_address'],
        status='created',
        amount=request.data['totalFare']
    )
    booking.description = request.data.get('description')
    booking.weight = request.data.get('weight')
    booking.dimensions = request.data.get('dimensions')
    booking.instructions = request.data.get('instructions')
    booking.distance_km = request.data.get('distance_km')
    booking.boxes = request.data.get('boxes')
    booking.helper_required = request.data.get('helper_required', False)

    booking.pickup_otp = str(random.randint(1000, 9999))
    booking.drop_otp = str(random.randint(1000, 9999))

    pickup = request.data.get('pickup_latlng')
    drop = request.data.get('drop_latlng')

    if pickup:
        lat = float(pickup['lat'])
        lng = float(pickup['lng'])
        booking.pickup_latlng = Point(lng, lat)

    if drop:
        lat = float(drop['lat'])
        lng = float(drop['lng'])
        booking.drop_latlng = Point(lng, lat)

    # Defensive check to ensure booking.id is set before notification
    if not booking.id:
        booking.save()
    else:
        booking.save()
    print(f"✅ Booking saved with ID: {booking.id}")

    # Send push notifications to partners within 10km of pickup location with endpoint ARN
    partners = Partner.objects.exclude(device_endpoint_arn__isnull=True)\
        .exclude(device_endpoint_arn='')\
        .filter(is_live=True, current_location__isnull=False)\
        .annotate(distance=Distance('current_location', booking.pickup_latlng))\
        .filter(distance__lte=10000)  # 10,000 meters = 10 km
    for partner in partners:
        print(f"device_endpoint_arn {partner.device_endpoint_arn}")
        payload = {
            "default": "Fallback message",
            "GCM": json.dumps({
                "notification": {
                    "title": "New Booking",
                    "body": f"Customer Name {booking.customer}"
                },
                "data": {
                    "booking_id": booking.id
                }
            })
        }
        print(f"📦 SNS Payload for {partner.device_endpoint_arn}: {json.dumps(payload)}")
        try:
            send_push_notification(
                partner.device_endpoint_arn,
                payload=payload
            )
        except Exception:
            continue  # Log or handle failure if needed

    return Response(BookingSerializer(booking).data, status=status.HTTP_201_CREATED)


# New view to validate pickup OTP for a booking
@api_view(['POST'])
def validate_pickup_otp(request):
    """
    Validate the pickup OTP for a booking.
    """
    booking_id = request.data.get('booking_id')
    if not booking_id:
        return Response({'error': 'booking_id is required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        booking = Booking.objects.get(pk=booking_id)
    except Booking.DoesNotExist:
        return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)

    input_otp = request.data.get('otp')
    if not input_otp:
        return Response({'error': 'OTP is required'}, status=status.HTTP_400_BAD_REQUEST)

    if booking.pickup_otp == input_otp:
        booking.status = 'in_transit'
        booking.save()
        return Response({
            'success': 'OTP validated successfully',
            'drop_location': booking.drop_location,
            'drop_latlng': {
                'lat': booking.drop_latlng.y if booking.drop_latlng else None,
                'lng': booking.drop_latlng.x if booking.drop_latlng else None
            }
        }, status=status.HTTP_200_OK)
    else:
        return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
def validate_drop_otp(request):
    """
    Validate the drop OTP for a booking.
    """
    booking_id = request.data.get('booking_id')
    if not booking_id:
        return Response({'error': 'booking_id is required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        booking = Booking.objects.get(pk=booking_id)
    except Booking.DoesNotExist:
        return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)

    input_otp = request.data.get('otp')
    if not input_otp:
        return Response({'error': 'OTP is required'}, status=status.HTTP_400_BAD_REQUEST)

    if booking.drop_otp == input_otp:
        booking.status = 'completed'
        booking.save()

        # Reduce rides_remaining from PartnerWallet
        try:
            partner_wallet = booking.partner.wallet
            if partner_wallet.rides_remaining > 0:
                partner_wallet.rides_remaining -= 1
                partner_wallet.save()
        except Exception as e:
            print(f"⚠️ Error updating partner wallet: {e}")

        return Response({
            'success': 'Drop OTP validated successfully',
            'message': f'Drop complete for booking {booking.id}'
        }, status=status.HTTP_200_OK)
    else:
        return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)