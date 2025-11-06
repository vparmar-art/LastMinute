#!/bin/bash
# Script to add SNS permissions to the ECS task execution role
# This allows the running application to send SNS messages

set -e

ACCOUNT_ID="957118235304"
ROLE_NAME="lastminute-us-east-1-ecs-task-exec"
REGION="us-east-1"
POLICY_NAME="lastminute-us-east-1-ecs-ssm-access"

echo "🔐 Adding SNS permissions to ECS task execution role"
echo "=================================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

echo "Updating IAM policy for role: $ROLE_NAME"
echo ""

# Get current policy document
CURRENT_POLICY=$(aws iam get-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "$POLICY_NAME" \
    --region "$REGION" \
    --query 'PolicyDocument' \
    --output json)

# Create updated policy with SNS permissions
UPDATED_POLICY=$(echo "$CURRENT_POLICY" | python3 -c "
import sys
import json

policy = json.load(sys.stdin)

# Find the Statement array
statements = policy.get('Statement', [])

# Check if SNS permissions already exist
has_sns = False
for stmt in statements:
    if 'sns:Publish' in stmt.get('Action', []):
        has_sns = True
        break

if not has_sns:
    # Add SNS permissions statement
    sns_statement = {
        'Effect': 'Allow',
        'Action': [
            'sns:Publish',
            'sns:CreatePlatformEndpoint',
            'sns:GetEndpointAttributes',
            'sns:SetEndpointAttributes'
        ],
        'Resource': '*'
    }
    statements.append(sns_statement)
    policy['Statement'] = statements
    print(json.dumps(policy, indent=2))
else:
    print(json.dumps(policy, indent=2))
    sys.exit(1)
")

if [ $? -eq 0 ]; then
    # Update the policy
    echo "$UPDATED_POLICY" > /tmp/updated_policy.json
    
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "$POLICY_NAME" \
        --policy-document file:///tmp/updated_policy.json \
        --region "$REGION"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Successfully added SNS permissions to IAM role"
        echo ""
        echo "📋 Permissions added:"
        echo "   - sns:Publish"
        echo "   - sns:CreatePlatformEndpoint"
        echo "   - sns:GetEndpointAttributes"
        echo "   - sns:SetEndpointAttributes"
        echo ""
        echo "⚠️  Note: You may need to restart your ECS tasks for the changes to take effect"
        echo ""
        rm -f /tmp/updated_policy.json
    else
        echo "❌ Failed to update IAM policy"
        rm -f /tmp/updated_policy.json
        exit 1
    fi
else
    echo "✅ SNS permissions already exist in the policy"
fi

