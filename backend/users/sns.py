import boto3
import json
import logging
from django.conf import settings

# Initialize SNS client
sns = boto3.client('sns', region_name='us-east-1')  # Replace region if needed

logger = logging.getLogger(__name__)

def register_device_with_sns(fcm_token):
    """
    Registers an FCM device token with AWS SNS and returns the endpoint ARN.
    - fcm_token: the FCM token from the device
    - platform_arn: the ARN of the SNS platform application (GCM/FCM)
    """
    try:
        logger.info(f"Attempting to register FCM token with SNS: {fcm_token[:20]}...")
        
        if not fcm_token or fcm_token.strip() == '':
            logger.error("Empty or invalid FCM token provided")
            raise ValueError("Invalid FCM token")
            
        if not settings.AWS_SNS_ARN:
            logger.error("AWS_SNS_ARN not configured in settings")
            raise ValueError("AWS SNS ARN not configured")
            
        response = sns.create_platform_endpoint(
            PlatformApplicationArn=settings.AWS_SNS_ARN,
            Token=fcm_token
        )
        
        endpoint_arn = response['EndpointArn']
        logger.info(f"Successfully registered device with SNS. Endpoint ARN: {endpoint_arn}")
        return endpoint_arn
        
    except Exception as e:
        logger.error(f"Failed to register device with SNS: {str(e)}")
        logger.error(f"FCM Token: {fcm_token[:20]}...")
        logger.error(f"SNS ARN: {settings.AWS_SNS_ARN}")
        raise e

def send_sms(phone_number, message):
    """
    Sends an SMS message using AWS SNS.
    - phone_number: recipient number in E.164 format (e.g., '+919876543210')
    - message: the OTP or message text to send
    """
    try:
        logger.info(f"Sending SMS to {phone_number}: {message[:50]}...")
        response = sns.publish(
            PhoneNumber=phone_number,
            Message=message
        )
        logger.info(f"SMS sent successfully. Message ID: {response.get('MessageId')}")
        return response
    except Exception as e:
        logger.error(f"Failed to send SMS to {phone_number}: {str(e)}")
        raise e