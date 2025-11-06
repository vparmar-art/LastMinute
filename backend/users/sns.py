import boto3
import json
import logging
import os
from django.conf import settings

logger = logging.getLogger(__name__)

def get_sns_client():
    """
    Get SNS client using the default credential chain.
    
    In ECS Fargate, credentials are provided via:
    1. Task Role (via AWS_CONTAINER_CREDENTIALS_RELATIVE_URI) - preferred
    2. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) - fallback
    
    The default credential chain will automatically use the appropriate source.
    """
    region = os.getenv('AWS_REGION', 'us-east-1')
    
    # Check if we're in ECS Fargate (has container credentials URI)
    container_credentials_uri = os.getenv('AWS_CONTAINER_CREDENTIALS_RELATIVE_URI')
    access_key = os.getenv('AWS_ACCESS_KEY_ID')
    local_dev = os.getenv('LOCAL_DEV', 'False').lower() == 'true'
    
    if container_credentials_uri:
        logger.info("ECS Fargate detected - using task role credentials via container credentials endpoint")
    elif access_key:
        # Check if credentials are KMS-encrypted (start with 'kms:')
        if access_key.startswith('kms:'):
            if local_dev:
                logger.warning("⚠️  AWS_ACCESS_KEY_ID is KMS-encrypted in local development.")
                logger.warning("⚠️  KMS-encrypted credentials cannot be used directly.")
                logger.info("🔄 Attempting to use AWS CLI credentials (~/.aws/credentials) instead...")
                # Unset KMS-encrypted credentials to allow boto3 to use default credential chain
                # This will check ~/.aws/credentials, which is the standard way for local dev
                os.environ.pop('AWS_ACCESS_KEY_ID', None)
                os.environ.pop('AWS_SECRET_ACCESS_KEY', None)
                os.environ.pop('AWS_SESSION_TOKEN', None)
                logger.info("✅ Removed KMS-encrypted env vars. Using default credential chain (AWS CLI credentials).")
            else:
                logger.warning("⚠️  AWS_ACCESS_KEY_ID appears to be KMS-encrypted. This should be decrypted by ECS.")
                logger.warning("⚠️  If this fails, ensure the execution role has KMS decrypt permissions.")
        else:
            logger.info("Using credentials from environment variables")
    else:
        logger.info("No AWS credentials in environment. Using default credential chain (AWS CLI credentials).")
    
    try:
        # Use default credential chain - this works in both ECS Fargate (task role) 
        # and with environment variables
        # The default chain checks in this order:
        # 1. Environment variables
        # 2. ECS container credentials (AWS_CONTAINER_CREDENTIALS_RELATIVE_URI)
        # 3. EC2 instance metadata
        # 4. Shared credentials file
        session = boto3.Session()
        client = session.client('sns', region_name=region)
        
        # Test credentials by getting caller identity (if possible)
        try:
            sts_client = session.client('sts', region_name=region)
            identity = sts_client.get_caller_identity()
            account_id = identity.get('Account', 'unknown')
            logger.info(f"✅ Created SNS client - credentials verified (Account: {account_id})")
        except Exception as sts_error:
            logger.warning(f"Could not verify credentials via STS: {sts_error}")
            logger.info("✅ Created SNS client - credentials will be verified on first API call")
        
        return client
        
    except Exception as e:
        error_msg = str(e)
        logger.error(f"❌ Failed to create SNS client: {error_msg}")
        logger.error(f"Error type: {type(e).__name__}")
        
        if 'Unable to locate credentials' in error_msg or 'NoCredentialsError' in error_msg:
            logger.error("CREDENTIAL ERROR: No AWS credentials available.")
            logger.error("Possible causes:")
            logger.error("  1. ECS task definition missing 'taskRoleArn' (required for Fargate)")
            logger.error("  2. Task role doesn't have SNS permissions")
            logger.error("  3. Environment variables (AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY) not set")
            logger.error("  4. ECS tasks haven't been restarted after adding task role")
            logger.error("")
            logger.error("SOLUTION:")
            logger.error("  Option A: Add 'taskRoleArn' to task definition pointing to a role with SNS permissions")
            logger.error("  Option B: Ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set in task definition secrets")
        
        raise e

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
        
        # Get fresh client in case credentials changed
        sns_client = get_sns_client()
        response = sns_client.create_platform_endpoint(
            PlatformApplicationArn=settings.AWS_SNS_ARN,
            Token=fcm_token
        )
        
        endpoint_arn = response['EndpointArn']
        logger.info(f"Successfully registered device with SNS. Endpoint ARN: {endpoint_arn}")
        return endpoint_arn
        
    except Exception as e:
        error_msg = str(e)
        error_code = getattr(e, 'response', {}).get('Error', {}).get('Code', '') if hasattr(e, 'response') else ''
        
        # Check for specific AWS account errors
        is_account_suspended = (
            'account is suspended' in error_msg.lower() or 
            'InvalidClientTokenId' in error_msg or 
            error_code == 'InvalidClientTokenId'
        )
        
        if is_account_suspended:
            # Extract account ID from ARN (format: arn:aws:sns:region:account-id:app/...)
            account_id = "unknown"
            if settings.AWS_SNS_ARN:
                try:
                    arn_parts = settings.AWS_SNS_ARN.split(':')
                    if len(arn_parts) >= 5:
                        account_id = arn_parts[4]
                except Exception:
                    pass
            
            logger.error("=" * 80)
            logger.error("AWS ACCOUNT SUSPENDED - Cannot register device with SNS")
            logger.error("=" * 80)
            logger.error(f"The AWS account ({account_id}) is suspended.")
            logger.error("Possible causes:")
            logger.error("  1. AWS account billing issue - payment method invalid or payment overdue")
            logger.error("  2. AWS account security violation or terms of service violation")
            logger.error("")
            logger.error("ACTION REQUIRED:")
            logger.error(f"  1. Log into AWS Console (account: {account_id}) and check account status")
            logger.error("  2. Verify billing/payment method is valid in Billing Dashboard")
            logger.error("  3. Contact AWS Support to resolve account suspension")
            logger.error("=" * 80)
            logger.error(f"FCM Token: {fcm_token[:20]}...")
            logger.error(f"SNS ARN: {settings.AWS_SNS_ARN}")
            # Create a custom exception with more context
            raise ValueError(f"AWS Account Suspended: {error_msg}. Please resolve account suspension in AWS Console.")
        else:
            logger.error(f"Failed to register device with SNS: {error_msg}")
            if 'AccessDenied' in error_msg or 'UnauthorizedOperation' in error_msg:
                logger.error("Permission denied - IAM role may not have SNS permissions")
            elif 'InvalidParameter' in error_msg:
                logger.error("Invalid SNS ARN or FCM token format")
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
        # Get fresh client in case credentials changed
        sns_client = get_sns_client()
        response = sns_client.publish(
            PhoneNumber=phone_number,
            Message=message
        )
        logger.info(f"SMS sent successfully. Message ID: {response.get('MessageId')}")
        return response
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Failed to send SMS to {phone_number}: {error_msg}")
        
        # Provide helpful error messages for common issues
        if 'Unable to locate credentials' in error_msg or 'NoCredentialsError' in error_msg:
            logger.error("CREDENTIAL ERROR: IAM role credentials not available.")
            logger.error("Possible causes:")
            logger.error("  1. ECS task execution role doesn't have SNS permissions (check IAM policy)")
            logger.error("  2. ECS tasks haven't been restarted after adding SNS permissions")
            logger.error("  3. IAM role is not available in the ECS task environment")
            logger.error("  4. Task definition doesn't have executionRoleArn configured")
            logger.error("ACTION REQUIRED: Verify IAM role has SNS permissions and restart ECS tasks")
        elif 'account is suspended' in error_msg.lower() or 'InvalidClientTokenId' in error_msg:
            logger.error("AWS ACCOUNT SUSPENDED - Cannot send SMS. Check AWS account status and billing.")
        elif 'AccessDenied' in error_msg or 'UnauthorizedOperation' in error_msg:
            logger.error("Permission denied - IAM role may not have SNS SMS permissions")
            logger.error("Required IAM permissions: sns:Publish")
        elif 'IncompleteSignature' in error_msg or 'kms:' in error_msg or 'Credential must have exactly' in error_msg:
            local_dev = os.getenv('LOCAL_DEV', 'False').lower() == 'true'
            if local_dev:
                logger.error("=" * 80)
                logger.error("KMS-ENCRYPTED CREDENTIALS DETECTED IN LOCAL DEVELOPMENT")
                logger.error("=" * 80)
                logger.error("Your AWS credentials are KMS-encrypted and cannot be used directly.")
                logger.error("")
                logger.error("SOLUTIONS:")
                logger.error("  1. Use plaintext credentials in your .env file for local development")
                logger.error("  2. Set LOCAL_DEV=true to skip SMS sending in local dev")
                logger.error("  3. Remove AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY from .env")
                logger.error("     and use AWS CLI credentials (~/.aws/credentials) instead")
                logger.error("=" * 80)
            else:
                logger.error("CREDENTIAL ERROR: KMS-encrypted credentials not properly decrypted.")
                logger.error("Possible causes:")
                logger.error("  1. ECS task execution role doesn't have KMS decrypt permissions")
                logger.error("  2. ECS tasks haven't been restarted after adding KMS permissions")
                logger.error("  3. SSM Parameter Store secrets are not being decrypted by ECS")
                logger.error("ACTION REQUIRED: Verify ECS execution role has KMS decrypt permissions")
        
        raise e