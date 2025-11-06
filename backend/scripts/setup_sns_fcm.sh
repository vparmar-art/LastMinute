#!/bin/bash
# Script to set up AWS SNS Platform Application for Firebase Cloud Messaging (FCM)

set -e

REGION="us-east-1"
PLATFORM_APPLICATION_NAME="last-minute"
ACCOUNT_ID="957118235304"

echo "📱 Setting up AWS SNS for Firebase Cloud Messaging"
echo "=================================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Prompt for FCM Server Key
echo "⚠️  IMPORTANT: You need the FCM SERVER KEY, not the API key from google-services.json"
echo ""
echo "To get your FCM Server Key:"
echo "1. Go to Firebase Console: https://console.firebase.google.com/"
echo "2. Select your project: lastminute-6b363"
echo "3. Click the gear icon ⚙️ next to 'Project Overview' → Project Settings"
echo "4. Go to the 'Cloud Messaging' tab"
echo "5. Look for 'Cloud Messaging API (Legacy)' section"
echo "6. Copy the 'Server key' (it should start with 'AAAA' and be much longer)"
echo ""
echo "❌ DO NOT use the API key from google-services.json (starts with 'AIza')"
echo "✅ You need the Server key from Cloud Messaging API (Legacy)"
echo ""
read -p "Enter your FCM Server Key: " FCM_SERVER_KEY

if [ -z "$FCM_SERVER_KEY" ]; then
    echo "❌ FCM Server Key is required"
    exit 1
fi

# Validate the key format
if [[ "$FCM_SERVER_KEY" =~ ^AIza ]]; then
    echo ""
    echo "❌ ERROR: This looks like an API key from google-services.json, not a Server key!"
    echo "   API keys start with 'AIza' - these don't work with SNS"
    echo "   Server keys start with 'AAAA' and are much longer"
    echo ""
    echo "Please get the Server key from:"
    echo "Firebase Console > Project Settings > Cloud Messaging > Cloud Messaging API (Legacy) > Server key"
    exit 1
fi

if [[ ! "$FCM_SERVER_KEY" =~ ^AAAA ]]; then
    echo ""
    echo "⚠️  WARNING: Server keys usually start with 'AAAA'"
    echo "   Are you sure this is the correct Server key from Cloud Messaging API (Legacy)?"
    read -p "Continue anyway? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        exit 1
    fi
fi

echo ""
echo "Creating SNS Platform Application for GCM/FCM..."

# Create Platform Application
PLATFORM_ARN=$(aws sns create-platform-application \
    --name "$PLATFORM_APPLICATION_NAME" \
    --platform "GCM" \
    --attributes "PlatformCredential=$FCM_SERVER_KEY" \
    --region "$REGION" \
    --query 'PlatformApplicationArn' \
    --output text)

if [ $? -eq 0 ]; then
    echo "✅ Successfully created SNS Platform Application"
    echo "   Platform ARN: $PLATFORM_ARN"
    echo ""
    
    # Verify the ARN matches what's in the task definition
    EXPECTED_ARN="arn:aws:sns:us-east-1:$ACCOUNT_ID:app/GCM/$PLATFORM_APPLICATION_NAME"
    if [ "$PLATFORM_ARN" == "$EXPECTED_ARN" ]; then
        echo "✅ Platform ARN matches task definition configuration"
    else
        echo "⚠️  Warning: Platform ARN doesn't match task definition"
        echo "   Expected: $EXPECTED_ARN"
        echo "   Got:      $PLATFORM_ARN"
        echo ""
        echo "   Update your task definition with: $PLATFORM_ARN"
    fi
    
    echo ""
    echo "🎉 SNS Platform Application setup complete!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Verify your ECS task execution role has SNS permissions:"
    echo "   - sns:Publish"
    echo "   - sns:CreatePlatformEndpoint"
    echo ""
    echo "2. The platform ARN is already configured in your task definition"
    echo ""
    echo "3. Test by creating a booking - partners should receive push notifications"
    
else
    echo "❌ Failed to create SNS Platform Application"
    exit 1
fi

