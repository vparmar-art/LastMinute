import boto3
import json
from django.conf import settings

# Initialize SNS client
sns = boto3.client('sns', region_name='us-east-1')  # Replace region if needed

def register_device_with_sns(fcm_token):
    """
    Registers an FCM device token with AWS SNS and returns the endpoint ARN.
    - fcm_token: the FCM token from the device
    - platform_arn: the ARN of the SNS platform application (GCM/FCM)
    """
    response = sns.create_platform_endpoint(
        PlatformApplicationArn=settings.AWS_SNS_ARN,
        Token=fcm_token
    )
    return response['EndpointArn']

def send_sms(phone_number, message):
    """
    Sends an SMS message using AWS SNS.
    - phone_number: recipient number in E.164 format (e.g., '+919876543210')
    - message: the OTP or message text to send
    """
    response = sns.publish(
        PhoneNumber=phone_number,
        Message=message
    )
    return response