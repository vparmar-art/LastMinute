import boto3
import json
import logging
import os
import botocore.session
from botocore.credentials import InstanceMetadataProvider, InstanceMetadataFetcher

logger = logging.getLogger(__name__)

def get_sns_client():
    """
    Get SNS client that ALWAYS uses IAM role credentials, ignoring environment variables.
    
    This is the root cause fix: We create a botocore session with a credential provider chain
    that ONLY uses instance metadata (IAM role), completely bypassing environment variables,
    config files, and shared credentials files which may contain corrupted KMS-encrypted values.
    """
    region = os.getenv('AWS_REGION', 'us-east-1')
    
    logger.info("Creating SNS client - forcing IAM role credentials (bypassing env vars)")
    
    # CRITICAL: Unset ALL AWS credential-related environment variables to prevent any
    # credential provider from reading them. This includes AWS_PROFILE which might point
    # to a credentials file with corrupted values.
    original_access_key = os.environ.pop('AWS_ACCESS_KEY_ID', None)
    original_secret_key = os.environ.pop('AWS_SECRET_ACCESS_KEY', None)
    original_session_token = os.environ.pop('AWS_SESSION_TOKEN', None)
    original_profile = os.environ.pop('AWS_PROFILE', None)
    original_default_region = os.environ.pop('AWS_DEFAULT_REGION', None)
    
    if original_access_key or original_secret_key:
        logger.info(f"Unset AWS credential env vars (access_key: {bool(original_access_key)}, secret_key: {bool(original_secret_key)})")
    
    try:
        # Create a completely fresh botocore session to avoid any cached credentials
        # Using get_session() creates a new session instance each time
        session = botocore.session.Session()
        
        # Create an instance metadata provider that ONLY uses IAM role credentials
        # This completely bypasses env vars, config files, and shared credentials
        instance_metadata_fetcher = InstanceMetadataFetcher(
            timeout=1000,
            num_attempts=2
        )
        instance_provider = InstanceMetadataProvider(
            iam_role_fetcher=instance_metadata_fetcher
        )
        
        # Get the credential resolver and replace its provider chain
        credential_resolver = session.get_component('credential_provider')
        
        # CRITICAL: Replace the entire provider list with ONLY instance metadata provider
        # This ensures NO other credential sources are checked (env vars, files, etc.)
        credential_resolver._providers = [instance_provider]
        
        # Also clear any cached credentials in the resolver
        if hasattr(credential_resolver, '_last_credentials'):
            credential_resolver._last_credentials = None
        
        # Try to resolve credentials NOW to verify they come from IAM role
        # This will help us debug if credentials are being resolved correctly
        try:
            credentials = credential_resolver.load_credentials()
            if credentials:
                # Log partial credential info (don't log full secret key for security)
                access_key_preview = credentials.access_key[:8] + '...' if credentials.access_key else 'None'
                logger.info(f"Resolved credentials from IAM role (access_key starts with: {access_key_preview})")
                # Verify it's NOT a KMS ciphertext
                if credentials.access_key and credentials.access_key.startswith('kms:'):
                    logger.error("⚠️  WARNING: Credentials still contain KMS prefix! This should not happen.")
                    raise ValueError("Credentials resolved from IAM role contain KMS prefix - this indicates a configuration issue")
            else:
                logger.warning("⚠️  No credentials resolved from IAM role - this might cause issues")
        except Exception as cred_error:
            logger.warning(f"Could not pre-resolve credentials (this is OK, they'll be resolved on first API call): {cred_error}")
        
        # Create the SNS client using this session with the custom credential provider
        client = session.create_client('sns', region_name=region)
        
        logger.info("✅ Created SNS client using IAM role-only credentials (env vars completely bypassed)")
        # Note: We do NOT restore env vars because they might be corrupted KMS ciphertext
        # The client will use IAM role credentials for all API calls
        return client
        
    except Exception as e:
        logger.error(f"❌ Failed to create SNS client with IAM role: {str(e)}")
        logger.error(f"Error type: {type(e).__name__}")
        
        # Only restore env vars if client creation failed
        if original_access_key:
            os.environ['AWS_ACCESS_KEY_ID'] = original_access_key
        if original_secret_key:
            os.environ['AWS_SECRET_ACCESS_KEY'] = original_secret_key
        if original_session_token:
            os.environ['AWS_SESSION_TOKEN'] = original_session_token
        
        raise e

def send_push_notification(endpoint_arn, payload):
    """
    Sends a push notification to the device registered with SNS endpoint ARN.
    - endpoint_arn: The ARN of the device endpoint in SNS.
    - payload: Dict with notification payload (GCM format)
    
    Returns the SNS publish response or raises an exception on failure.
    """
    # Check if this might be a mock endpoint ARN (from local development)
    # Log a warning but still try to send - SNS will reject it if invalid
    if 'mock-app' in endpoint_arn or '123456789012' in endpoint_arn:
        local_dev = os.getenv('LOCAL_DEV', 'False').lower() == 'true'
        if not local_dev:
            logger.warning(f"⚠️  Detected possible mock endpoint ARN (from local dev): {endpoint_arn[:50]}...")
            logger.warning("Attempting to send anyway - SNS will reject if invalid. Partner should re-login to register device.")
    
    # Validate endpoint ARN format
    if '/app/GCM/' in endpoint_arn and '/endpoint/' not in endpoint_arn:
        error_msg = f"Invalid ARN: This is a platform application ARN, not an endpoint ARN: {endpoint_arn}"
        logger.error(error_msg)
        logger.error("The partner's device_endpoint_arn field contains the platform ARN instead of an endpoint ARN.")
        logger.error("This means the partner's device was never properly registered with SNS.")
        logger.error("The partner needs to re-login so their FCM token can be registered with SNS.")
        raise ValueError(error_msg)
    
    try:
        # Get SNS client - this uses IAM role ONLY, completely bypassing env vars
        sns_client = get_sns_client()
        
        # Make the API call - client is configured to use IAM role only
        logger.info(f"Publishing push notification to SNS endpoint: {endpoint_arn[:50]}...")
        response = sns_client.publish(
            TargetArn=endpoint_arn,
            Message=json.dumps(payload),
            MessageStructure='json'
        )
        
        message_id = response.get('MessageId')
        logger.info(f"✅ Successfully sent push notification. Message ID: {message_id}")
        return response
    except Exception as e:
        error_msg = str(e)
        logger.error(f"❌ Failed to send push notification to {endpoint_arn}: {error_msg}")
        
        # Provide helpful error messages for common issues
        if 'IncompleteSignature' in error_msg or 'kms:' in error_msg or 'Credential must have exactly' in error_msg:
            logger.error("CREDENTIAL ERROR: This should not happen with IAM role-only credential provider.")
            logger.error("Possible causes:")
            logger.error("  1. ECS task execution role doesn't have SNS permissions (check IAM policy)")
            logger.error("  2. ECS tasks haven't been restarted after adding SNS permissions")
            logger.error("  3. IAM role is not available in the ECS task environment")
            logger.error("ACTION REQUIRED: Verify IAM role has SNS permissions and restart ECS tasks")
        elif 'EndpointDisabled' in error_msg or 'NotFound' in error_msg:
            logger.error(f"SNS endpoint not found or disabled: {endpoint_arn[:50]}...")
            logger.error("The device endpoint may have been deleted or disabled. Partner needs to re-register device.")
        elif 'InvalidParameter' in error_msg or 'Invalid' in error_msg:
            logger.error(f"Invalid parameter error: {error_msg}")
            # Check if this is the UUID length error (mock endpoint ARN issue)
            if 'UUID must be encoded in exactly 36 characters' in error_msg or 'endpointId' in error_msg:
                logger.error("This appears to be a mock endpoint ARN from local development.")
                logger.error("The partner needs to re-login so their device can be registered with a real SNS endpoint.")
                logger.error("Action: Partner should re-login to register their device with production SNS.")
        elif 'NoCredentialsError' in error_msg or 'Unable to locate credentials' in error_msg:
            logger.error("NO CREDENTIALS ERROR: IAM role credentials not available.")
            logger.error("This usually means the ECS task doesn't have an execution role configured.")
            logger.error("Verify the task definition has 'executionRoleArn' set correctly.")
        
        # Re-raise the exception so the caller can handle it
        raise e
