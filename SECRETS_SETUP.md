# Secrets Setup Guide

This guide explains how to set up secure secret management for the LastMinute application.

## Overview

The application uses environment variables for configuration. In production, these are encrypted using AWS KMS.

## Environment Variables

### Required Variables

```bash
# Django Settings
SECRET_KEY=your-django-secret-key
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,*

# Database Settings
DB_NAME=postgres
DB_USER=your-db-user
DB_PASSWORD=your-db-password
DB_HOST=your-db-host.amazonaws.com
DB_PORT=5432

# AWS Settings
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
AWS_STORAGE_BUCKET_NAME=your-s3-bucket
AWS_MEDIA_BUCKET_NAME=your-media-bucket
AWS_S3_REGION_NAME=us-east-1
AWS_SNS_ARN=your-sns-arn
```

## Local Development

1. **Create `.env` file** in the project root:
   ```bash
   cp .env.example .env
   ```

2. **Fill in your actual values** (never commit this file):
   ```bash
   # Edit .env with your actual secrets
   nano .env
   ```

3. **Start the application**:
   ```bash
   cd backend
   python manage.py runserver
   ```

## Production Deployment

### Using AWS KMS (Recommended)

1. **Set up KMS encryption** (see `AWS_KMS_SETUP.md`)
2. **Use encrypted environment variables** in ECS task definition
3. **Never commit secrets** to version control

### Using Environment Variables

1. **Set environment variables** in your deployment platform
2. **Use secure secret management** (AWS Secrets Manager, etc.)
3. **Rotate secrets regularly**

## Security Best Practices

### ✅ Do's

- Use AWS KMS for production secrets
- Rotate secrets regularly
- Use environment variables for configuration
- Monitor secret access and usage
- Use least privilege access policies
- Encrypt secrets in transit and at rest

### ❌ Don'ts

- Never commit secrets to version control
- Don't use hardcoded secrets in code
- Don't share secrets via unsecured channels
- Don't use default/weak secrets
- Don't store secrets in plain text files

## File Structure

```
LastMinute/
├── .env.example          # Template (safe to commit)
├── .env                  # Local secrets (never commit)
├── .env.kms             # KMS encrypted secrets (never commit)
├── backend/
│   ├── main/
│   │   ├── settings.py  # Uses environment variables
│   │   └── kms_utils.py # KMS decryption utilities
│   └── scripts/
│       └── setup_kms_secrets.py # KMS setup script
└── ui/
    ├── customer/
    │   └── lib/secrets.dart # Flutter secrets
    ├── partner/
    │   └── lib/secrets.dart # Flutter secrets
    └── marketplace/
        └── lib/secrets.dart # Flutter secrets
```

## Flutter Apps

Each Flutter app has its own `secrets.dart` file:

```dart
// lib/secrets.dart
class Secrets {
  static const String apiBaseUrl = 'YOUR_API_BASE_URL';
  static const String firebaseProjectId = 'YOUR_FIREBASE_PROJECT_ID';
  // Add other app-specific secrets
}
```

## Troubleshooting

### Common Issues

1. **Environment variables not loading**
   - Check file path and permissions
   - Verify variable names match settings.py

2. **KMS decryption failing**
   - Check AWS credentials and permissions
   - Verify KMS key exists and is accessible

3. **Database connection issues**
   - Verify database credentials
   - Check network connectivity

### Verification

```bash
# Test Django settings
cd backend
python manage.py check

# Test KMS decryption
python -c "from main.kms_utils import get_kms_decryptor; print(get_kms_decryptor().get_decrypted_env_var('TEST_VAR'))"
```

## Migration Guide

### From Hardcoded Secrets

1. **Identify all hardcoded secrets** in your codebase
2. **Move to environment variables** using the patterns above
3. **Update deployment configuration** to use secure secret management
4. **Test thoroughly** before deploying to production

### To AWS KMS

1. **Follow the AWS KMS setup guide**
2. **Encrypt all secrets** using the provided script
3. **Update ECS task definition** with encrypted secrets
4. **Deploy and verify** everything works correctly

## Security Checklist

- [ ] All secrets moved to environment variables
- [ ] No hardcoded secrets in code
- [ ] Production secrets encrypted with KMS
- [ ] Environment files added to .gitignore
- [ ] Secrets rotated regularly
- [ ] Access to secrets properly controlled
- [ ] Monitoring and alerting configured
- [ ] Backup and recovery procedures in place 