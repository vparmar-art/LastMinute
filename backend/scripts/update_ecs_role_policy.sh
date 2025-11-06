#!/bin/bash
# Script to update ECS task execution role with SSM permissions
# Usage: ./update_ecs_role_policy.sh

set -e

REGION="us-east-1"
ACCOUNT_ID="957118235304"
ROLE_NAME="lastminute-us-east-1-ecs-task-exec"
POLICY_NAME="lastminute-us-east-1-ecs-ssm-access"
PARAMETER_PREFIX="/lastminute"

echo "🔐 Updating ECS Task Execution Role with SSM Permissions"
echo "========================================================="
echo ""

# Create policy document
POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "ssm:GetParameter",
        "ssm:GetParametersByPath"
      ],
      "Resource": [
        "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter${PARAMETER_PREFIX}/SECRET_KEY",
        "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter${PARAMETER_PREFIX}/DB_PASSWORD",
        "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter${PARAMETER_PREFIX}/AWS_ACCESS_KEY_ID",
        "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter${PARAMETER_PREFIX}/AWS_SECRET_ACCESS_KEY"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "ssm.${REGION}.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish",
        "sns:CreatePlatformEndpoint",
        "sns:GetEndpointAttributes",
        "sns:SetEndpointAttributes"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

# Save policy to temp file
TEMP_POLICY=$(mktemp)
echo "$POLICY_DOC" > "$TEMP_POLICY"

echo "Updating inline policy: ${POLICY_NAME}"
echo ""

# Put the policy
aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "${POLICY_NAME}" \
  --policy-document "file://${TEMP_POLICY}" \
  --region "${REGION}"

# Clean up temp file
rm "$TEMP_POLICY"

echo ""
echo "✅ Policy updated successfully!"
echo ""
echo "The role ${ROLE_NAME} now has permissions to:"
echo "  - Read SSM parameters from ${PARAMETER_PREFIX}/*"
echo "  - Decrypt KMS-encrypted parameters"
echo "  - Publish SNS messages (sns:Publish)"
echo "  - Create SNS platform endpoints (sns:CreatePlatformEndpoint)"
echo ""
echo "⚠️  IMPORTANT: You need to restart your ECS tasks for the changes to take effect!"
echo "   Run: aws ecs update-service --cluster <cluster-name> --service <service-name> --force-new-deployment"
echo ""

