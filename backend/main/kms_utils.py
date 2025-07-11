import boto3
import base64
import os
from botocore.exceptions import ClientError
import logging

logger = logging.getLogger(__name__)

class KMSDecryptor:
    """
    Utility class for decrypting secrets using AWS KMS
    """
    
    def __init__(self, region_name='us-east-1'):
        self.region_name = region_name
        
        # Store original environment variables that might conflict
        self.original_env = {}
        self._backup_env_vars()
        
        # Create KMS client with clean environment
        self.kms_client = self._create_kms_client()
        
        # Restore original environment
        self._restore_env_vars()
    
    def _backup_env_vars(self):
        """Backup environment variables that might conflict with KMS"""
        conflict_vars = ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']
        for var in conflict_vars:
            if var in os.environ:
                self.original_env[var] = os.environ[var]
                del os.environ[var]
    
    def _restore_env_vars(self):
        """Restore original environment variables"""
        for var, value in self.original_env.items():
            os.environ[var] = value
    
    def _create_kms_client(self):
        """Create KMS client with clean environment"""
        try:
            # Get AWS credentials from shared credentials file or IAM role
            session = boto3.Session()
            return session.client('kms', region_name=self.region_name)
        except Exception as e:
            logger.error(f"Failed to create KMS client: {e}")
            return None
    
    def decrypt_value(self, encrypted_value):
        """
        Decrypt a base64-encoded encrypted value using AWS KMS
        
        Args:
            encrypted_value (str): Base64-encoded encrypted value
            
        Returns:
            str: Decrypted value
        """
        if not self.kms_client:
            logger.error("KMS client not available")
            return None
            
        try:
            # Decode base64
            encrypted_bytes = base64.b64decode(encrypted_value)
            
            # Decrypt using KMS
            response = self.kms_client.decrypt(
                CiphertextBlob=encrypted_bytes
            )
            
            # Return decrypted value as string
            decrypted_value = response['Plaintext'].decode('utf-8')
            return decrypted_value
            
        except ClientError as e:
            logger.error(f"KMS decryption failed: {e}")
            return None
        except Exception as e:
            logger.error(f"Error decrypting value: {e}")
            return None
    
    def get_decrypted_env_var(self, env_var_name, default=None):
        """
        Get an environment variable, decrypting it if it's encrypted
        
        Args:
            env_var_name (str): Name of the environment variable
            default: Default value if environment variable is not set
            
        Returns:
            str: Decrypted value or default
        """
        encrypted_value = os.getenv(env_var_name)
        
        if encrypted_value is None:
            return default
        
        # Check if the value is encrypted (starts with 'kms:')
        if encrypted_value.startswith('kms:'):
            # Remove 'kms:' prefix and decrypt
            encrypted_data = encrypted_value[4:]
            decrypted_value = self.decrypt_value(encrypted_data)
            if decrypted_value:
                return decrypted_value
            else:
                return default
        else:
            # Value is not encrypted, return as-is
            return encrypted_value

def get_kms_decryptor():
    """
    Get a KMS decryptor instance
    
    Returns:
        KMSDecryptor: Configured KMS decryptor
    """
    region = os.getenv('AWS_DEFAULT_REGION', 'us-east-1')
    return KMSDecryptor(region_name=region) 