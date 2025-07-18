import json
import logging
from django.contrib.gis.geos import Point
from django.contrib.gis.db.models.functions import Distance
from rest_framework import status, serializers
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Booking
from users.models import Customer, Partner
from .serializers import BookingSerializer
from users.serializers.partner import PartnerSerializer
from .sns import send_push_notification
from users.models.token import Token
import random
from vehicles.models import VehicleType
from django.utils import timezone

logger = logging.getLogger(__name__)

@api_view(['GET'])
def booking_list(request):
    """
    List all bookings.
    """
    customer_id = request.query_params.get('customer')
    partner_id = request.query_params.get('partner')

    bookings = Booking.objects.all()
    if customer_id:
        bookings = bookings.filter(customer__id=customer_id)
    if partner_id:
        bookings = bookings.filter(partner__id=partner_id)

    serializer = BookingSerializer(bookings, many=True)
    return Response(serializer.data)

@api_view(['GET', 'PUT'])
def booking_detail(request, booking_id):
    """
    Retrieve or update a booking instance.
    """
    try:
        booking = Booking.objects.get(pk=booking_id)
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
def update_booking_status(request, booking_id):
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
        booking = Booking.objects.get(pk=booking_id)
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

    # Extract and log vehicle_type
    vehicle_type_param = request.data.get('vehicle_type')
    logger.info(f"Vehicle type requested: {vehicle_type_param}")
    vehicle_type_obj = None
    if vehicle_type_param is not None:
        try:
            vehicle_type_obj = VehicleType.objects.get(id=int(vehicle_type_param))
        except (ValueError, VehicleType.DoesNotExist):
            try:
                vehicle_type_obj = VehicleType.objects.get(name=vehicle_type_param)
            except VehicleType.DoesNotExist:
                return Response({'error': 'Invalid vehicle_type'}, status=status.HTTP_400_BAD_REQUEST)

    # Booking type and scheduled time
    booking_type = request.data.get('booking_type', 'immediate')
    scheduled_time = request.data.get('scheduled_time')
    if booking_type == 'scheduled':
        if not scheduled_time:
            return Response({'error': 'scheduled_time is required for scheduled bookings'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            scheduled_time_dt = timezone.make_aware(timezone.datetime.fromisoformat(scheduled_time))
        except Exception:
            return Response({'error': 'Invalid scheduled_time format. Use ISO 8601.'}, status=status.HTTP_400_BAD_REQUEST)
        if scheduled_time_dt <= timezone.now():
            return Response({'error': 'scheduled_time must be in the future'}, status=status.HTTP_400_BAD_REQUEST)
    else:
        scheduled_time_dt = None

    # Create booking with status 'created'
    booking = Booking(
        customer=customer,
        pickup_location=request.data['pickup_address'],
        drop_location=request.data['drop_address'],
        status='created',
        amount=request.data['totalFare'],
        vehicle_type=vehicle_type_obj,
        booking_type=booking_type,
        scheduled_time=scheduled_time_dt
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

    # Only send push notifications for immediate bookings
    if booking_type == 'immediate':
        # Send push notifications to partners within 10km of pickup location with endpoint ARN and matching vehicle_type
        partners = Partner.objects.exclude(device_endpoint_arn__isnull=True)\
            .exclude(device_endpoint_arn='')\
            .filter(is_live=True, current_location__isnull=False)\
            .filter(vehicle_type=vehicle_type_obj)\
            .annotate(distance=Distance('current_location', booking.pickup_latlng))\
            .filter(distance__lte=10000)  # 10,000 meters = 10 km
        
        logger.info(f"Found {partners.count()} partners within 10km of pickup location and vehicle_type '{vehicle_type_obj}'")
        
        for partner in partners:
            payload = {
                "default": "Booking request",
                "GCM": json.dumps({
                    "notification": {
                        "title": f"New Booking: {booking.pickup_location} → {booking.drop_location}",
                        "body": f"Fare: ₹{booking.amount} | Tap to view details",
                        "sound": "notification_alert"
                    },
                    "data": {
                        "booking_id": booking.id,
                        "pickup": booking.pickup_location,
                        "drop": booking.drop_location,
                        "fare": booking.amount
                    }
                })
            }
            try:
                logger.info(f"Sending notification to partner {partner.id} (phone: {partner.phone_number})")
                response = send_push_notification(
                    partner.device_endpoint_arn,
                    payload=payload
                )
                logger.info(f"Successfully sent notification to partner {partner.id}. Message ID: {response.get('MessageId')}")
            except Exception as e:
                logger.error(f"Failed to send notification to partner {partner.id}: {str(e)}")
                # Continue with other partners even if one fails
                continue

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
            logger.error(f"Error updating partner wallet: {e}")

        return Response({
            'success': 'Drop OTP validated successfully',
            'message': f'Drop complete for booking {booking.id}'
        }, status=status.HTTP_200_OK)
    else:
        return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
def booking_full_details(request, booking_id):
    """
    Retrieve full booking details including nested partner info and lat/lng objects.
    """
    try:
        booking = Booking.objects.get(pk=booking_id)
    except Booking.DoesNotExist:
        return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)

    data = BookingSerializer(booking).data

    if booking.pickup_latlng:
        data['pickup_latlng'] = {
            'lat': booking.pickup_latlng.y,
            'lng': booking.pickup_latlng.x
        }
    if booking.drop_latlng:
        data['drop_latlng'] = {
            'lat': booking.drop_latlng.y,
            'lng': booking.drop_latlng.x
        }

    if booking.partner:
        data['partner_details'] = PartnerSerializer(booking.partner).data
    else:
        data['partner_details'] = None

    return Response(data)

@api_view(['POST'])
def submit_ride_rating(request, booking_id):
    """
    Submit rating and review for a completed ride.
    """
    try:
        booking = Booking.objects.get(pk=booking_id)
    except Booking.DoesNotExist:
        return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)

    if not booking.is_completed:
        return Response({'error': 'Can only rate completed rides'}, status=status.HTTP_400_BAD_REQUEST)

    if booking.ride_rating_submitted:
        return Response({'error': 'Rating already submitted for this ride'}, status=status.HTTP_400_BAD_REQUEST)

    rating = request.data.get('rating')
    review = request.data.get('review', '')

    if not rating or not isinstance(rating, int) or rating < 1 or rating > 5:
        return Response({'error': 'Valid rating (1-5) is required'}, status=status.HTTP_400_BAD_REQUEST)

    booking.rating = rating
    booking.review = review
    booking.ride_rating_submitted = True
    booking.save()

    # Update partner's average rating
    if booking.partner:
        partner = booking.partner
        partner_ratings = Booking.objects.filter(
            partner=partner, 
            rating__isnull=False
        ).values_list('rating', flat=True)
        
        if partner_ratings:
            avg_rating = sum(partner_ratings) / len(partner_ratings)
            partner.rating = round(avg_rating, 1)
            partner.save()

    return Response({
        'success': 'Rating submitted successfully',
        'rating': rating,
        'review': review
    }, status=status.HTTP_200_OK)

@api_view(['POST'])
def report_emergency(request, booking_id):
    """
    Report an emergency during a ride.
    """
    try:
        booking = Booking.objects.get(pk=booking_id)
    except Booking.DoesNotExist:
        return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)

    emergency_type = request.data.get('emergency_type', 'general')
    description = request.data.get('description', '')
    customer_location = request.data.get('customer_location')

    booking.emergency_contacted = True
    booking.customer_feedback = f"Emergency: {emergency_type} - {description}"
    booking.save()

    # Log emergency for monitoring
    logger.warning(f"Emergency reported for booking {booking_id}: {emergency_type} - {description}")

    return Response({
        'success': 'Emergency reported successfully',
        'message': 'Support team has been notified'
    }, status=status.HTTP_200_OK)