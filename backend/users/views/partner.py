from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework.permissions import IsAuthenticated
from users.models.partner import Partner, PartnerOTP
from users.models.token import Token  
from twilio.rest import Client
from django.conf import settings
import random
import logging
import uuid
from ..sns import register_device_with_sns
from rest_framework.parsers import JSONParser
from django.contrib.gis.geos import Point
from django.core.cache import cache
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from users.serializers import PartnerSerializer  # ensure this import exists
from django.utils import timezone
from users.sns import send_sms
from users.utils import update_partner_location

logger = logging.getLogger(__name__)

def check_partner_wallet(partner):
    wallet = partner.wallet
    if not wallet:
        return False

    # Ride-based plan: check credits
    if wallet.rides_remaining > 0:
        return True

    # Duration-based plan: check validity
    if wallet.valid_until and wallet.valid_until >= timezone.now():
        return True

    return False

class PartnerSendOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = request.data.get('phone_number')

        if not phone_number:
            logger.warning("Send OTP request missing phone number")
            return Response({"error": "Phone number is required"}, status=400)

        # Generate 4-digit OTP
        code = str(random.randint(1000, 9999))
        partner, _ = Partner.objects.get_or_create(
            phone_number=phone_number
        )
        session_id = request.session.session_key or request.session.save() or request.session.session_key

        # Store only the latest OTP per partner
        otp, created = PartnerOTP.objects.update_or_create(
            partner=partner,
            defaults={
                'code': code,
                'session_id': session_id,
                'is_verified': False
            }
        )

        logger.info(f"OTP generated for {phone_number} - {code}")

        send_sms(f"+91{phone_number}", f"OTP generated for {phone_number} - {code}")

        return Response({"message": "OTP sent successfully"})


class PartnerVerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = request.data.get('phone_number')
        otp_input = request.data.get('otp')

        logger.info(f"OTP verification attempt for phone number: {phone_number}")

        try:
            otp = PartnerOTP.objects.filter(partner__phone_number=phone_number, is_verified=False).latest('created_at')
        except PartnerOTP.DoesNotExist:
            logger.warning(f"No OTP found or already verified for phone number: {phone_number}")
            return Response({'error': 'No OTP found or already verified'}, status=400)

        if otp.is_expired():
            logger.warning(f"OTP expired for phone number: {phone_number}")
            return Response({'error': 'OTP expired'}, status=400)

        if otp.code != otp_input:
            logger.warning(f"Invalid OTP entered for phone number: {phone_number}")
            return Response({'error': 'Invalid OTP'}, status=400)

        otp.is_verified = True
        otp.save()
        logger.info(f"OTP verified successfully for phone number: {phone_number}")

        # Get or create the partner
        partner, created = Partner.objects.get_or_create(phone_number=phone_number)

        # Generate a token for the partner using the custom Token model
        token_key = str(uuid.uuid4())  # Example of using UUID for token
        token, _ = Token.objects.get_or_create(partner=partner, defaults={'key': token_key})
        logger.info(f"Token generated for partner: {phone_number} {token.key}")

        # Update device endpoint ARN if provided
        device_endpoint_arn = request.data.get('device_endpoint_arn')
        if device_endpoint_arn:
            try:
                logger.info(f"Registering device for partner {phone_number} with FCM token: {device_endpoint_arn[:20]}...")
                endpoint_arn = register_device_with_sns(device_endpoint_arn)
                partner.device_endpoint_arn = endpoint_arn
                partner.save()
                logger.info(f"Successfully registered device for partner {phone_number}. Endpoint ARN: {endpoint_arn}")
            except Exception as e:
                logger.error(f"Failed to register device with SNS for {phone_number}: {str(e)}")
                # Don't fail the login, just log the error
                # The partner can still login but won't receive push notifications

        return Response({'token': token.key})

class PartnerProfileView(APIView):
    permission_classes = [AllowAny]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        partner_id = request.query_params.get('id')

        if partner_id:
            try:
                partner = Partner.objects.get(id=partner_id)
            except Partner.DoesNotExist:
                return Response({'error': 'Partner not found'}, status=404)
        else:
            token_key = request.headers.get('Authorization', '').replace('Token ', '')
            if not token_key:
                return Response({'error': 'Authorization token missing'}, status=401)

            try:
                token = Token.objects.get(key=token_key)
                partner = token.partner
            except Token.DoesNotExist:
                return Response({'error': 'Invalid token'}, status=401)

        serializer = PartnerSerializer(partner)
        return Response(serializer.data)
    
    def put(self, request):
        token_key = request.headers.get('Authorization', '').replace('Token ', '')
        if not token_key:
            return Response({'error': 'Authorization token missing'}, status=401)

        try:
            token = Token.objects.get(key=token_key)
            partner = token.partner
        except Token.DoesNotExist:
            return Response({'error': 'Invalid token'}, status=401)

        data = request.data

        # partner is trying to go live
        if partner.is_live == False and data['is_live'] == True:
            can_go_live = check_partner_wallet(partner)
            if not can_go_live:
                return Response({'error': 'No active plan. Please recharge to go live.'}, status=403)

        # Update partner fields safely, only if keys exist
        for field in ['owner_full_name', 'vehicle_type', 'vehicle_number', 'registration_number',
                      'driver_name', 'driver_phone', 'driver_license', 'is_agreed_to_terms',
                      'current_step', 'is_rejected', 'rejection_reason', 'is_live']:
            if field in data:
                setattr(partner, field, data[field])

        # Handle selfie upload if present
        if 'selfie' in request.FILES:
            partner.selfie = request.FILES['selfie']

        # Save the updated partner object
        partner.save()

        return Response({'message': 'Profile updated successfully'})

class PartnerLocationView(APIView):
    parser_classes = [JSONParser]

    def post(self, request):
        token_key = request.headers.get('Authorization', '').replace('Token ', '')
        if not token_key:
            return Response({'error': 'Authorization token missing'}, status=401)

        try:
            token = Token.objects.get(key=token_key)
        except Token.DoesNotExist:
            return Response({'error': 'Invalid token'}, status=401)

        partner_id = token.partner.id

        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')
        if latitude is None or longitude is None:
            return Response({'error': 'Latitude and longitude are required'}, status=400)

        result = update_partner_location(partner_id, latitude, longitude)

        if 'error' in result:
            return Response({'error': result['error']}, status=404)
        if result.get('skipped'):
            return Response({'message': result['reason']})
        return Response({'message': 'Location updated successfully'})

    def get(self, request):
        partner_id = request.query_params.get('partner_id')
        if not partner_id:
            return Response({'error': 'partner_id is required'}, status=400)

        try:
            partner = Partner.objects.get(id=partner_id)
        except Partner.DoesNotExist:
            return Response({'error': 'Partner not found'}, status=404)

        if not partner.current_location:
            return Response({'error': 'Location not available'}, status=404)

        return Response({
            'latitude': partner.current_location.y,
            'longitude': partner.current_location.x
        })