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

# Serializer for Booking
class BookingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Booking
        fields = ['id', 'customer', 'partner', 'pickup_location', 
                  'drop_location', 'pickup_latlng', 'drop_latlng',
                  'pickup_time', 'drop_time', 'status', 'amount', 
                  'description', 'weight', 'dimensions', 'instructions', 'distance_km',
                  'created_at', 'modified_at']

@api_view(['GET', 'POST'])
def booking_list(request):
    """
    List all bookings or create a new booking.
    """
    if request.method == 'GET':
        bookings = Booking.objects.all()
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
        # Update status or other details
        if 'status' in request.data:
            booking.status = request.data['status']
        if 'pickup_location' in request.data:
            booking.pickup_location = request.data['pickup_location']
        if 'drop_location' in request.data:
            booking.drop_location = request.data['drop_location']
        if 'pickup_time' in request.data:
            booking.pickup_time = request.data['pickup_time']
        if 'drop_time' in request.data:
            booking.drop_time = request.data['drop_time']
        if 'description' in request.data:
            booking.description = request.data['description']
        if 'weight' in request.data:
            booking.weight = request.data['weight']
        if 'dimensions' in request.data:
            booking.dimensions = request.data['dimensions']
        if 'instructions' in request.data:
            booking.instructions = request.data['instructions']
        if 'distance_km' in request.data:
            booking.distance_km = request.data['distance_km']

        booking.save()
        return Response(BookingSerializer(booking).data)

@api_view(['POST'])
def update_booking_status(request, pk):
    """
    Update the status of a booking (e.g., in_transit, arriving, completed).
    """
    try:
        booking = Booking.objects.get(pk=pk)
    except Booking.DoesNotExist:
        return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)

    if 'status' in request.data:
        booking.status = request.data['status']
        booking.save()
        return Response(BookingSerializer(booking).data, status=status.HTTP_200_OK)
    else:
        return Response({'error': 'Status field is required'}, status=status.HTTP_400_BAD_REQUEST)


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
        # amount=request.data['amount'],
        status='created',
        amount=request.data['totalFare']
    )
    booking.description = request.data.get('description')
    booking.weight = request.data.get('weight')
    booking.dimensions = request.data.get('dimensions')
    booking.instructions = request.data.get('instructions')
    booking.distance_km = request.data.get('distance_km')

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