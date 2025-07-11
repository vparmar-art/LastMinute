#!/usr/bin/env python3
"""
Test script to verify Firebase notification setup and troubleshoot issues.
Run this script to check if notifications are working properly.
"""

import os
import sys
import django
import boto3
import json
import logging

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'main.settings')
django.setup()

from django.conf import settings
from users.models import Partner
from bookings.sns import send_push_notification
from users.sns import register_device_with_sns

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_sns_connection():
    """Test SNS connection and configuration"""
    print("🔍 Testing SNS Connection...")
    
    try:
        sns = boto3.client('sns', region_name='us-east-1')
        response = sns.list_platform_applications()
        print("✅ SNS connection successful")
        print(f"📱 Platform applications: {len(response['PlatformApplications'])}")
        
        # Check if our platform application exists
        platform_arn = settings.AWS_SNS_ARN
        print(f"🎯 Target Platform ARN: {platform_arn}")
        
        return True
    except Exception as e:
        print(f"❌ SNS connection failed: {str(e)}")
        return False

def test_partner_registration():
    """Test partner device registration"""
    print("\n🔍 Testing Partner Device Registration...")
    
    # Get a test partner
    partners = Partner.objects.filter(device_endpoint_arn__isnull=False).exclude(device_endpoint_arn='')
    
    if not partners.exists():
        print("❌ No partners with device endpoint ARN found")
        return False
    
    partner = partners.first()
    print(f"👤 Testing with partner: {partner.phone_number}")
    print(f"📱 Current endpoint ARN: {partner.device_endpoint_arn}")
    
    return True

def test_notification_sending():
    """Test sending a notification to a partner"""
    print("\n🔍 Testing Notification Sending...")
    
    # Get a partner with endpoint ARN
    partners = Partner.objects.filter(device_endpoint_arn__isnull=False).exclude(device_endpoint_arn='')
    
    if not partners.exists():
        print("❌ No partners with device endpoint ARN found")
        return False
    
    partner = partners.first()
    print(f"👤 Sending test notification to partner: {partner.phone_number}")
    
    # Create test payload
    payload = {
        "default": "Test notification from LastMinute",
        "GCM": json.dumps({
            "notification": {
                "title": "Test Notification",
                "body": "This is a test notification from LastMinute"
            },
            "data": {
                "booking_id": "999",
                "test": "true"
            }
        })
    }
    
    try:
        response = send_push_notification(partner.device_endpoint_arn, payload)
        print(f"✅ Notification sent successfully!")
        print(f"📨 Message ID: {response.get('MessageId')}")
        return True
    except Exception as e:
        print(f"❌ Failed to send notification: {str(e)}")
        return False

def check_partner_status():
    """Check partner status and device registration"""
    print("\n🔍 Checking Partner Status...")
    
    total_partners = Partner.objects.count()
    partners_with_arn = Partner.objects.filter(device_endpoint_arn__isnull=False).exclude(device_endpoint_arn='').count()
    live_partners = Partner.objects.filter(is_live=True).count()
    
    print(f"📊 Total partners: {total_partners}")
    print(f"📱 Partners with device ARN: {partners_with_arn}")
    print(f"🟢 Live partners: {live_partners}")
    
    # Show some partner details
    print("\n👥 Partner Details:")
    for partner in Partner.objects.all()[:5]:  # Show first 5 partners
        status = "🟢 Live" if partner.is_live else "🔴 Offline"
        has_arn = "📱 Yes" if partner.device_endpoint_arn else "❌ No"
        print(f"  {partner.phone_number}: {status} | Device ARN: {has_arn}")

def main():
    """Main test function"""
    print("🚀 LastMinute Firebase Notification Test")
    print("=" * 50)
    
    # Test SNS connection
    sns_ok = test_sns_connection()
    
    # Check partner status
    check_partner_status()
    
    # Test partner registration
    registration_ok = test_partner_registration()
    
    # Test notification sending
    if sns_ok and registration_ok:
        notification_ok = test_notification_sending()
    else:
        notification_ok = False
    
    print("\n" + "=" * 50)
    print("📋 Test Results:")
    print(f"  SNS Connection: {'✅ OK' if sns_ok else '❌ FAILED'}")
    print(f"  Partner Registration: {'✅ OK' if registration_ok else '❌ FAILED'}")
    print(f"  Notification Sending: {'✅ OK' if notification_ok else '❌ FAILED'}")
    
    if not sns_ok:
        print("\n🔧 Troubleshooting SNS:")
        print("  1. Check AWS credentials are configured")
        print("  2. Verify AWS_SNS_ARN in settings")
        print("  3. Ensure SNS platform application exists")
    
    if not registration_ok:
        print("\n🔧 Troubleshooting Registration:")
        print("  1. Check if partners have valid FCM tokens")
        print("  2. Verify SNS platform application ARN")
        print("  3. Check AWS permissions for SNS")
    
    if not notification_ok:
        print("\n🔧 Troubleshooting Notifications:")
        print("  1. Check partner device endpoint ARNs")
        print("  2. Verify SNS permissions")
        print("  3. Check FCM token validity")

if __name__ == "__main__":
    main() 