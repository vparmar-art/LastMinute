#!/bin/bash
# Script to verify ECS secrets configuration
# Usage: ./verify_ecs_secrets.sh

set -e

REGION="us-east-1"
PARAMETER_PREFIX="/lastminute"
ACCOUNT_ID="957118235304"

echo "🔍 Verifying ECS Secrets Configuration"
echo "========================================"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

echo "1. Checking SSM Parameters..."
echo "----------------------------"
REQUIRED_PARAMS=("SECRET_KEY" "DB_PASSWORD" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY")

for param in "${REQUIRED_PARAMS[@]}"; do
    full_path="${PARAMETER_PREFIX}/${param}"
    if aws ssm get-parameter --name "${full_path}" --region "${REGION}" --query "Parameter.Name" --output text 2>/dev/null; then
        echo "✅ ${param} exists"
    else
        echo "❌ ${param} NOT FOUND at ${full_path}"
        echo "   Run: ./scripts/setup_ssm_secrets.sh to create it"
    fi
done

echo ""
echo "2. Verifying Task Execution Role Permissions..."
echo "-----------------------------------------------"
ROLE_NAME="lastminute-us-east-1-ecs-task-exec"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Check if role exists
if aws iam get-role --role-name "${ROLE_NAME}" --query "Role.RoleName" --output text 2>/dev/null; then
    echo "✅ Role ${ROLE_NAME} exists"
    
    # Check attached policies
    echo ""
    echo "   Checking attached policies..."
    POLICIES=$(aws iam list-attached-role-policies --role-name "${ROLE_NAME}" --query "AttachedPolicies[].PolicyArn" --output text)
    if echo "$POLICIES" | grep -q "AmazonECSTaskExecutionRolePolicy"; then
        echo "   ✅ AmazonECSTaskExecutionRolePolicy attached"
    else
        echo "   ⚠️  AmazonECSTaskExecutionRolePolicy not found"
    fi
    
    # Check inline policies
    echo ""
    echo "   Checking inline policies for SSM permissions..."
    INLINE_POLICIES=$(aws iam list-role-policies --role-name "${ROLE_NAME}" --query "PolicyNames" --output text)
    if [ -n "$INLINE_POLICIES" ]; then
        echo "   Found inline policies: $INLINE_POLICIES"
        for policy in $INLINE_POLICIES; do
            POLICY_DOC=$(aws iam get-role-policy --role-name "${ROLE_NAME}" --policy-name "$policy" --query "PolicyDocument" --output text)
            if echo "$POLICY_DOC" | grep -q "ssm:GetParameter"; then
                echo "   ✅ Policy '$policy' has SSM permissions"
            fi
        done
    else
        echo "   ⚠️  No inline policies found"
        echo "   You may need to add SSM permissions to the role"
    fi
else
    echo "❌ Role ${ROLE_NAME} NOT FOUND"
    echo "   Create the role or update the task definition with the correct role ARN"
fi

echo ""
echo "3. Checking Task Definition..."
echo "------------------------------"
TASK_FAMILY="last-minute-task"

# Get latest task definition
LATEST_TASK=$(aws ecs describe-task-definition \
    --task-definition "${TASK_FAMILY}" \
    --region "${REGION}" \
    --query "taskDefinition.revision" \
    --output text 2>/dev/null || echo "0")

if [ "$LATEST_TASK" != "0" ]; then
    echo "✅ Found task definition: ${TASK_FAMILY}:${LATEST_TASK}"
    
    # Check if secrets are configured
    SECRETS_COUNT=$(aws ecs describe-task-definition \
        --task-definition "${TASK_FAMILY}" \
        --region "${REGION}" \
        --query "length(taskDefinition.containerDefinitions[0].secrets)" \
        --output text 2>/dev/null || echo "0")
    
    if [ "$SECRETS_COUNT" -gt "0" ]; then
        echo "✅ Task definition has ${SECRETS_COUNT} secrets configured"
        echo ""
        echo "   Configured secrets:"
        aws ecs describe-task-definition \
            --task-definition "${TASK_FAMILY}" \
            --region "${REGION}" \
            --query "taskDefinition.containerDefinitions[0].secrets[*].[name,valueFrom]" \
            --output table
    else
        echo "❌ Task definition has NO secrets configured"
        echo "   Register the updated task definition:"
        echo "   aws ecs register-task-definition --cli-input-json file://ecs/task-defination.json"
    fi
else
    echo "❌ Task definition ${TASK_FAMILY} NOT FOUND"
    echo "   Register it first:"
    echo "   aws ecs register-task-definition --cli-input-json file://ecs/task-defination.json"
fi

echo ""
echo "4. Summary and Next Steps..."
echo "-----------------------------"
echo ""
echo "If secrets are missing:"
echo "  1. Create SSM parameters: ./scripts/setup_ssm_secrets.sh"
echo ""
echo "If task definition needs updating:"
echo "  1. Register task definition:"
echo "     aws ecs register-task-definition --cli-input-json file://ecs/task-defination.json"
echo ""
echo "If role permissions are missing:"
echo "  1. Attach policy with SSM permissions to ${ROLE_NAME}"
echo ""
echo "If service is using old task definition:"
echo "  1. Update service to use latest task definition:"
echo "     aws ecs update-service --cluster <cluster-name> --service <service-name> --force-new-deployment"

