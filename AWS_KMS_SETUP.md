# AWS KMS Setup Guide

This guide explains how to set up AWS KMS for secure secret management in your ECS deployment.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Python with boto3 installed
- Access to create KMS keys

## Step 1: Create KMS Key

```bash
# Create a new KMS key for your application
aws kms create-key \
  --description "LastMinute App Secrets" \
  --key-usage ENCRYPT_DECRYPT \
  --origin AWS_KMS

# Create an alias for easier reference
aws kms create-alias \
  --alias-name alias/lastminute-secrets \
  --target-key-id YOUR_KEY_ID
```

## Step 2: Set Up Environment Variables

Before running the encryption script, set your actual secrets as environment variables:

```bash
# Set your actual secrets (DO NOT COMMIT THESE)
export SECRET_KEY="your-actual-django-secret-key"
export DB_PASSWORD="your-actual-database-password"
export AWS_ACCESS_KEY_ID="your-actual-aws-access-key"
export AWS_SECRET_ACCESS_KEY="your-actual-aws-secret-key"
```

## Step 3: Encrypt Secrets

Use the provided script to encrypt your secrets:

```bash
cd backend
python scripts/setup_kms_secrets.py
```

The script will:
- Encrypt all secrets using your KMS key
- Generate a `.env.kms` file with encrypted values
- Create an ECS task definition with KMS references

## Step 4: Update ECS Task Definition

The script generates `ecs-task-definition.json` with encrypted secrets. Update it with your account details:

```json
{
  "family": "lastminute-backend",
  "executionRoleArn": "arn:aws:iam::YOUR-ACCOUNT:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::YOUR-ACCOUNT:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "django-app",
      "image": "YOUR-ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/lastminute-backend:latest",
      "secrets": [
        {
          "name": "SECRET_KEY",
          "valueFrom": "kms:alias/lastminute-secrets:your-encrypted-secret-key"
        },
        {
          "name": "DB_PASSWORD",
          "valueFrom": "kms:alias/lastminute-secrets:your-encrypted-db-password"
        },
        {
          "name": "AWS_ACCESS_KEY_ID",
          "valueFrom": "kms:alias/lastminute-secrets:your-encrypted-access-key"
        },
        {
          "name": "AWS_SECRET_ACCESS_KEY",
          "valueFrom": "kms:alias/lastminute-secrets:your-encrypted-secret-key"
        }
      ]
    }
  ]
}
```

## Step 5: Deploy to ECS

```bash
# Register the task definition
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json

# Create or update your ECS service
aws ecs create-service \
  --cluster your-cluster \
  --service-name lastminute-backend \
  --task-definition lastminute-backend \
  --desired-count 1
```

## Security Benefits

- ✅ All secrets encrypted using AWS KMS
- ✅ No plaintext secrets in environment variables
- ✅ Secrets encrypted in transit and at rest
- ✅ IAM policies control who can decrypt secrets
- ✅ Proper secret management practices
- ✅ Encrypted secrets in transit and at rest

## Troubleshooting

### Check KMS Key Status
```bash
aws kms describe-key --key-id alias/lastminute-secrets
```

### Verify Encryption
```bash
# Test encryption/decryption
aws kms encrypt \
  --key-id alias/lastminute-secrets \
  --plaintext "test-secret"

aws kms decrypt \
  --ciphertext-blob fileb://encrypted.bin
```

### Common Issues

1. **Permission Denied**: Ensure your IAM role has KMS permissions
2. **Key Not Found**: Verify the KMS key alias exists
3. **Decryption Failed**: Check that the encrypted values are correct

## Key Rotation

### Enable Key Rotation
```bash
aws kms enable-key-rotation --key-id alias/lastminute-secrets
```

### Rotate Keys Manually
1. Create new KMS key
2. Re-encrypt all secrets with new key
3. Update ECS task definition
4. Deploy updated service

## Security Checklist

- [ ] KMS key created with proper permissions
- [ ] All secrets encrypted using KMS
- [ ] ECS task definition updated with encrypted secrets
- [ ] IAM roles configured with KMS permissions
- [ ] Key rotation enabled
- [ ] Secrets not committed to version control
- [ ] Environment variables secured
- [ ] Production deployment tested

## Best Practices

1. **Never commit secrets** to version control
2. **Use environment variables** for local development
3. **Rotate keys regularly** for enhanced security
4. **Monitor KMS usage** with CloudWatch
5. **Use least privilege** IAM policies
6. **Test encryption/decryption** before deployment 