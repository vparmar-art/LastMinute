from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from django.contrib.auth import get_user_model
import random
import logging
from .models import OTP

# Initialize logger
logger = logging.getLogger(__name__)

User = get_user_model()

class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get('username')
        password = request.data.get('password')

        logger.info("Login attempt received")
        logger.debug(f"Username: {username}")

        user_exists = User.objects.filter(username=username).exists()
        logger.debug(f"User exists: {user_exists}")

        user = authenticate(username=username, password=password)
        if user:
            logger.info(f"User authenticated successfully: {username}")
            token, _ = Token.objects.get_or_create(user=user)
            return Response({'token': token.key})
        
        logger.warning(f"Invalid login attempt for username: {username}")
        return Response({'error': 'Invalid credentials'}, status=400)


class SendOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = request.data.get('phone_number')

        if not phone_number:
            logger.warning("Send OTP request missing phone number")
            return Response({"error": "Phone number is required"}, status=400)

        code = str(random.randint(1000, 9999))

        # Optionally tie to session
        session_id = request.session.session_key or request.session.save() or request.session.session_key

        otp = OTP.objects.create(
            phone_number=phone_number,
            code=code,
            session_id=session_id
        )

        print(f"Phone number: {phone_number} Generated OTP: {code}")

        logger.info(f"OTP generated for phone number: {phone_number}")
        logger.debug(f"Generated OTP: {code}")

        # Simulate sending SMS (replace with actual SMS sending logic)
        logger.info(f"Simulated sending OTP to {phone_number}")

        return Response({"message": "OTP sent successfully"})


class VerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone_number = request.data.get('phone_number')
        otp_input = request.data.get('otp')

        logger.info(f"OTP verification attempt for phone number: {phone_number}")

        try:
            otp = OTP.objects.filter(phone_number=phone_number, is_verified=False).latest('created_at')
        except OTP.DoesNotExist:
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

        # Get or create the user
        user, created = User.objects.get_or_create(phone_number=phone_number, defaults={
            'username': phone_number,
        })

        if created:
            logger.info(f"New user created for phone number: {phone_number}")
        else:
            logger.info(f"Existing user retrieved for phone number: {phone_number}")

        token, _ = Token.objects.get_or_create(user=user)
        logger.info(f"Token generated for user: {phone_number} {token.key}")
        return Response({'token': token.key})