from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from users.models.partner import Partner, PartnerOTP
from users.models.token import Token  # Now using the renamed Token model
from twilio.rest import Client
from django.conf import settings
import random
import logging
import uuid

logger = logging.getLogger(__name__)

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

        otp = PartnerOTP.objects.create(
            partner=partner,
            code=code,
            session_id=session_id
        )

        logger.info(f"OTP generated for {phone_number} - {code}")

        # Format phone number for WhatsApp (E.164 with 'whatsapp:' prefix)
        whatsapp_number = f'whatsapp:+91{phone_number}'

        try:
            client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
            message = client.messages.create(
                from_=settings.TWILIO_WHATSAPP_NUMBER,
                to=whatsapp_number,
                content_sid=settings.TWILIO_WHATSAPP_TEMPLATE_SID,
                content_variables=f'{{"1":"{code}"}}'
            )
            logger.info(f"WhatsApp OTP sent to {phone_number}, SID: {message.sid}")
        except Exception as e:
            logger.error(f"Failed to send WhatsApp OTP to {phone_number}: {str(e)}")
            return Response({"error": "Failed to send OTP"}, status=500)

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
        return Response({'token': token.key})

class PartnerProfileView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        token_key = request.headers.get('Authorization', '').replace('Token ', '')
        if not token_key:
            return Response({'error': 'Authorization token missing'}, status=401)

        try:
            token = Token.objects.get(key=token_key)
            partner = token.partner
        except Token.DoesNotExist:
            return Response({'error': 'Invalid token'}, status=401)

        profile_data = {
            'phone_number': partner.phone_number,
            'is_verified': partner.is_verified,  # Updated field
            'owner_full_name': partner.owner_full_name,
            'vehicle_type': partner.vehicle_type,
            'vehicle_number': partner.vehicle_number,
            'registration_number': partner.registration_number,
            'driver_name': partner.driver_name,
            'driver_license': partner.driver_license,
            'license_document': partner.license_document.url if partner.license_document else None,
            'registration_document': partner.registration_document.url if partner.registration_document else None,
            'selfie': partner.selfie.url if partner.selfie else None,
        }
        return Response({'profile': profile_data})