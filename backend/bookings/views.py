from rest_framework import status, serializers
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Booking
from users.models import Customer, Partner
from .serializers import BookingSerializer

# Serializer for Booking
class BookingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Booking
        fields = ['id', 'customer', 'partner', 'pickup_location', 
                  'drop_location', 'pickup_time', 'drop_time', 'status', 'amount', 
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