from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from users.models.customer import Customer, CustomerOTP
from users.models.token import Token  # Now using the renamed Token model
from twilio.rest import Client
from django.conf import settings
import random
import logging
import uuid
from users.sns import send_sms

logger = logging.getLogger(__name__)

class CustomerSendOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = request.data.get('phone_number')

        if not phone_number:
            logger.warning("Send OTP request missing phone number")
            return Response({"error": "Phone number is required"}, status=400)

        # Generate 4-digit OTP
        code = str(random.randint(1000, 9999))
        customer, _ = Customer.objects.get_or_create(phone_number=phone_number, defaults={"full_name": ""})
        session_id = request.session.session_key or request.session.save() or request.session.session_key

        otp = CustomerOTP.objects.create(
            customer=customer,
            code=code,
            session_id=session_id
        )

        logger.info(f"OTP generated for {phone_number} - {code}")

        send_sms(f"+91{phone_number}", f"OTP generated for {phone_number} - {code}")

        return Response({"message": "OTP sent successfully"})


class CustomerVerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = request.data.get('phone_number')
        otp_input = request.data.get('otp')

        logger.info(f"OTP verification attempt for phone number: {phone_number}")

        try:
            otp = CustomerOTP.objects.filter(customer__phone_number=phone_number, is_verified=False).latest('created_at')
        except CustomerOTP.DoesNotExist:
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

        # Get or create the customer
        customer, created = Customer.objects.get_or_create(phone_number=phone_number, defaults={'full_name': phone_number})

        if created:
            logger.info(f"New customer created for phone number: {phone_number}")
        else:
            logger.info(f"Existing customer retrieved for phone number: {phone_number}")

        # Generate a token for the customer using the custom Token model
        token_key = str(uuid.uuid4())  # Example of using UUID for token
        token, _ = Token.objects.get_or_create(customer=customer, defaults={'key': token_key})
        logger.info(f"Token generated for customer: {phone_number} {token.key}")
        return Response({'token': token.key, 'customer': customer.id})