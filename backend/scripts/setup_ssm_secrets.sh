#!/bin/bash
# Script to set up secrets in AWS Systems Manager Parameter Store
# for use with ECS task definitions

set -e

REGION="us-east-1"
PARAMETER_PREFIX="/lastminute"

echo "🔐 Setting up AWS SSM Parameters for LastMinute"
echo "================================================"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Function to set a parameter
set_parameter() {
    local param_name=$1
    local param_value=$2
    local full_path="${PARAMETER_PREFIX}/${param_name}"
    
    echo "Setting ${full_path}..."
    aws ssm put-parameter \
        --name "${full_path}" \
        --value "${param_value}" \
        --type "SecureString" \
        --region "${REGION}" \
        --overwrite \
        --no-cli-pager
    
    if [ $? -eq 0 ]; then
        echo "✅ ${param_name} set successfully"
    else
        echo "❌ Failed to set ${param_name}"
        exit 1
    fi
}

# Read secret values from environment variables or prompt for input
# NEVER hardcode secrets in this file - they will be detected by GitHub secret scanning

# Function to get a secret value (from env var or prompt)
get_secret() {
    local env_var_name=$1
    local prompt_text=$2
    local value="${!env_var_name}"
    
    if [ -z "$value" ]; then
        echo -n "${prompt_text}: "
        read -s value
        echo ""
    fi
    
    if [ -z "$value" ]; then
        echo "❌ Error: ${env_var_name} is required"
        exit 1
    fi
    
    echo "$value"
}

echo "Setting up SSM parameters..."
echo "Note: Secrets will be read from environment variables if set, otherwise you'll be prompted."
echo ""

# Get secrets from environment variables or prompt
SECRET_KEY=$(get_secret "SECRET_KEY" "Enter SECRET_KEY")
DB_PASSWORD=$(get_secret "DB_PASSWORD" "Enter DB_PASSWORD")
AWS_ACCESS_KEY_ID=$(get_secret "AWS_ACCESS_KEY_ID" "Enter AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY=$(get_secret "AWS_SECRET_ACCESS_KEY" "Enter AWS_SECRET_ACCESS_KEY")

# Set all parameters
set_parameter "SECRET_KEY" "${SECRET_KEY}"
set_parameter "DB_PASSWORD" "${DB_PASSWORD}"
set_parameter "AWS_ACCESS_KEY_ID" "${AWS_ACCESS_KEY_ID}"
set_parameter "AWS_SECRET_ACCESS_KEY" "${AWS_SECRET_ACCESS_KEY}"

echo ""
echo "🎉 All secrets have been set up in SSM Parameter Store!"
echo ""
echo "📋 Next steps:"
echo "1. Verify your ECS task execution role has permissions to read SSM parameters:"
echo "   - ssm:GetParameters"
echo "   - ssm:GetParameter"
echo "   - kms:Decrypt (SSM SecureString parameters use KMS encryption)"
echo ""
echo "2. Update your ECS service with the new task definition"
echo ""
echo "3. The secrets will be automatically decrypted and injected as environment variables in your container"

