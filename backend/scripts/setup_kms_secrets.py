#!/usr/bin/env python3
"""
Comprehensive script to set up AWS KMS and encrypt all backend secrets
"""

import boto3
import base64
import json
import sys
import os
from botocore.exceptions import ClientError

class KMSSecretManager:
    def __init__(self, region_name='us-east-1'):
        self.region_name = region_name
        self.kms_client = boto3.client('kms', region_name=region_name)
        self.key_id = None
        self.key_alias = 'alias/lastminute-secrets'
    
    def create_kms_key(self):
        """Create a new KMS key"""
        try:
            print("Creating KMS key...")
            response = self.kms_client.create_key(
                Description="LastMinute App Secrets",
                KeyUsage='ENCRYPT_DECRYPT',
                Origin='AWS_KMS'
            )
            
            self.key_id = response['KeyMetadata']['KeyId']
            print(f"✅ KMS key created: {self.key_id}")
            
            # Create alias
            try:
                self.kms_client.create_alias(
                    AliasName=self.key_alias,
                    TargetKeyId=self.key_id
                )
                print(f"✅ Alias created: {self.key_alias}")
            except ClientError as e:
                if e.response['Error']['Code'] == 'AlreadyExistsException':
                    print(f"⚠️  Alias {self.key_alias} already exists, updating...")
                    self.kms_client.update_alias(
                        AliasName=self.key_alias,
                        TargetKeyId=self.key_id
                    )
                else:
                    raise e
            
            return self.key_id
            
        except ClientError as e:
            print(f"❌ Error creating KMS key: {e}")
            return None
    
    def get_existing_key(self):
        """Get existing KMS key"""
        try:
            response = self.kms_client.describe_key(KeyId=self.key_alias)
            self.key_id = response['KeyMetadata']['KeyId']
            print(f"✅ Using existing KMS key: {self.key_id}")
            return self.key_id
        except ClientError as e:
            print(f"⚠️  No existing key found: {e}")
            return None
    
    def encrypt_value(self, plaintext):
        """Encrypt a value using KMS"""
        try:
            response = self.kms_client.encrypt(
                KeyId=self.key_id,
                Plaintext=plaintext.encode('utf-8')
            )
            
            encrypted_value = base64.b64encode(response['CiphertextBlob']).decode('utf-8')
            return f"kms:{encrypted_value}"
            
        except ClientError as e:
            print(f"❌ Error encrypting value: {e}")
            return None
    
    def encrypt_all_secrets(self):
        """Encrypt all backend secrets"""
        
        # Define all secrets that need encryption - USER MUST PROVIDE THESE
        secrets = {
            'DJANGO_SECRET_KEY': os.getenv('DJANGO_SECRET_KEY', 'YOUR_DJANGO_SECRET_KEY_HERE'),
            'DB_PASSWORD': os.getenv('DB_PASSWORD', 'YOUR_DB_PASSWORD_HERE'),
            'AWS_ACCESS_KEY_ID': os.getenv('AWS_ACCESS_KEY_ID', 'YOUR_AWS_ACCESS_KEY_ID_HERE'),
            'AWS_SECRET_ACCESS_KEY': os.getenv('AWS_SECRET_ACCESS_KEY', 'YOUR_AWS_SECRET_ACCESS_KEY_HERE'),
        }
        
        # Check if any secrets are still using placeholder values
        placeholder_secrets = []
        for secret_name, secret_value in secrets.items():
            if secret_value.startswith('YOUR_') and secret_value.endswith('_HERE'):
                placeholder_secrets.append(secret_name)
        
        if placeholder_secrets:
            print(f"\n❌ ERROR: The following secrets need to be provided:")
            for secret in placeholder_secrets:
                print(f"   - {secret}")
            print("\nPlease set these environment variables or update the script with actual values.")
            return {}
        
        encrypted_secrets = {}
        
        print("\n🔐 Encrypting secrets...")
        for secret_name, secret_value in secrets.items():
            print(f"Encrypting {secret_name}...")
            encrypted_value = self.encrypt_value(secret_value)
            
            if encrypted_value:
                encrypted_secrets[secret_name] = encrypted_value
                print(f"✅ {secret_name} encrypted successfully")
            else:
                print(f"❌ Failed to encrypt {secret_name}")
        
        return encrypted_secrets
    
    def generate_env_file(self, encrypted_secrets):
        """Generate .env file with encrypted values"""
        
        env_content = """# Django Settings
DJANGO_SECRET_KEY={DJANGO_SECRET_KEY}
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,*

# Database Settings
DB_NAME=postgres
DB_USER=vikash
DB_PASSWORD={DB_PASSWORD}
DB_HOST=last-minute-dev.cm96escgy66l.us-east-1.rds.amazonaws.com
DB_PORT=5432

# AWS Settings
AWS_ACCESS_KEY_ID={AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY={AWS_SECRET_ACCESS_KEY}
AWS_STORAGE_BUCKET_NAME=zappa-deployments-last-minute
AWS_MEDIA_BUCKET_NAME=lastminute-media-root
AWS_S3_REGION_NAME=us-east-1
AWS_SNS_ARN=arn:aws:sns:us-east-1:054037119505:app/GCM/notify-driver
""".format(**encrypted_secrets)
        
        # Write to .env file
        env_file_path = os.path.join(os.path.dirname(__file__), '..', '.env', '.env')
        os.makedirs(os.path.dirname(env_file_path), exist_ok=True)
        
        with open(env_file_path, 'w') as f:
            f.write(env_content)
        
        print(f"\n✅ Environment file created: {env_file_path}")
        return env_file_path
    
    def generate_ecs_task_definition(self, encrypted_secrets):
        """Generate ECS task definition with encrypted secrets"""
        
        task_definition = {
            "family": "lastminute-backend",
            "networkMode": "awsvpc",
            "requiresCompatibilities": ["FARGATE"],
            "cpu": "256",
            "memory": "512",
            "executionRoleArn": "arn:aws:iam::YOUR-ACCOUNT:role/ecsTaskExecutionRole",
            "taskRoleArn": "arn:aws:iam::YOUR-ACCOUNT:role/ecsTaskRole",
            "containerDefinitions": [
                {
                    "name": "django-app",
                    "image": "YOUR-ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/lastminute-backend:latest",
                    "essential": True,
                    "portMappings": [
                        {
                            "containerPort": 8000,
                            "protocol": "tcp"
                        }
                    ],
                    "environment": [
                        {
                            "name": "DEBUG",
                            "value": "False"
                        },
                        {
                            "name": "ALLOWED_HOSTS",
                            "value": "your-domain.com,*.your-domain.com"
                        },
                        {
                            "name": "DB_NAME",
                            "value": "postgres"
                        },
                        {
                            "name": "DB_USER",
                            "value": "vikash"
                        },
                        {
                            "name": "DB_HOST",
                            "value": "last-minute-dev.cm96escgy66l.us-east-1.rds.amazonaws.com"
                        },
                        {
                            "name": "DB_PORT",
                            "value": "5432"
                        },
                        {
                            "name": "AWS_MEDIA_BUCKET_NAME",
                            "value": "lastminute-media-root"
                        },
                        {
                            "name": "AWS_STORAGE_BUCKET_NAME",
                            "value": "zappa-deployments-last-minute"
                        },
                        {
                            "name": "AWS_S3_REGION_NAME",
                            "value": "us-east-1"
                        },
                        {
                            "name": "AWS_SNS_ARN",
                            "value": "arn:aws:sns:us-east-1:054037119505:app/GCM/notify-driver"
                        }
                    ],
                    "secrets": [
                        {
                            "name": "DJANGO_SECRET_KEY",
                            "valueFrom": f"kms:{self.key_alias}:{encrypted_secrets['DJANGO_SECRET_KEY'][4:]}"
                        },
                        {
                            "name": "DB_PASSWORD",
                            "valueFrom": f"kms:{self.key_alias}:{encrypted_secrets['DB_PASSWORD'][4:]}"
                        },
                        {
                            "name": "AWS_ACCESS_KEY_ID",
                            "valueFrom": f"kms:{self.key_alias}:{encrypted_secrets['AWS_ACCESS_KEY_ID'][4:]}"
                        },
                        {
                            "name": "AWS_SECRET_ACCESS_KEY",
                            "valueFrom": f"kms:{self.key_alias}:{encrypted_secrets['AWS_SECRET_ACCESS_KEY'][4:]}"
                        }
                    ],
                    "logConfiguration": {
                        "logDriver": "awslogs",
                        "options": {
                            "awslogs-group": "/ecs/lastminute-backend",
                            "awslogs-region": "us-east-1",
                            "awslogs-stream-prefix": "ecs"
                        }
                    }
                }
            ]
        }
        
        # Write task definition to file
        task_def_path = os.path.join(os.path.dirname(__file__), '..', 'ecs-task-definition.json')
        with open(task_def_path, 'w') as f:
            json.dump(task_definition, f, indent=2)
        
        print(f"\n✅ ECS task definition created: {task_def_path}")
        return task_def_path

def main():
    """Main function"""
    print("🔐 LastMinute KMS Secrets Setup")
    print("=" * 50)
    
    # Initialize KMS manager
    kms_manager = KMSSecretManager()
    
    # Try to get existing key, create if not exists
    key_id = kms_manager.get_existing_key()
    if not key_id:
        key_id = kms_manager.create_kms_key()
        if not key_id:
            print("❌ Failed to create or find KMS key")
            sys.exit(1)
    
    # Encrypt all secrets
    encrypted_secrets = kms_manager.encrypt_all_secrets()
    
    if not encrypted_secrets:
        print("❌ Failed to encrypt secrets")
        sys.exit(1)
    
    # Generate .env file
    env_file = kms_manager.generate_env_file(encrypted_secrets)
    
    # Generate ECS task definition
    task_def_file = kms_manager.generate_ecs_task_definition(encrypted_secrets)
    
    print("\n🎉 KMS setup completed successfully!")
    print("\n📋 Next steps:")
    print("1. Review the generated .env file")
    print("2. Update the ECS task definition with your account details")
    print("3. Deploy to ECS")
    print("4. Test the application")

if __name__ == "__main__":
    main() 