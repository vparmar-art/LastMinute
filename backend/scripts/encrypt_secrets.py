#!/usr/bin/env python3
"""
Utility script to encrypt secrets using AWS KMS for production deployment
"""

import boto3
import base64
import sys
import os
from botocore.exceptions import ClientError

def encrypt_with_kms(key_id, plaintext):
    """
    Encrypt a value using AWS KMS
    
    Args:
        key_id (str): KMS key ID or alias
        plaintext (str): Value to encrypt
        
    Returns:
        str: Base64-encoded encrypted value
    """
    try:
        kms_client = boto3.client('kms')
        
        response = kms_client.encrypt(
            KeyId=key_id,
            Plaintext=plaintext.encode('utf-8')
        )
        
        # Return base64-encoded encrypted value
        return base64.b64encode(response['CiphertextBlob']).decode('utf-8')
        
    except ClientError as e:
        print(f"Error encrypting with KMS: {e}")
        return None

def main():
    """
    Main function to encrypt secrets
    """
    if len(sys.argv) < 3:
        print("Usage: python encrypt_secrets.py <kms_key_id> <secret_value>")
        print("Example: python encrypt_secrets.py alias/my-key 'my-secret-value'")
        sys.exit(1)
    
    key_id = sys.argv[1]
    secret_value = sys.argv[2]
    
    print(f"Encrypting secret using KMS key: {key_id}")
    
    encrypted_value = encrypt_with_kms(key_id, secret_value)
    
    if encrypted_value:
        print(f"Encrypted value: kms:{encrypted_value}")
        print("\nAdd this to your environment variables:")
        print(f"export SECRET_NAME='kms:{encrypted_value}'")
    else:
        print("Failed to encrypt value")
        sys.exit(1)

if __name__ == "__main__":
    main() 