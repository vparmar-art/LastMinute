import boto3
import json

# Initialize SNS client
sns = boto3.client('sns', region_name='us-east-1')  # Replace region if needed

def send_push_notification(endpoint_arn, payload):
    """
    Sends a push notification to the device registered with SNS endpoint ARN.
    - endpoint_arn: The ARN of the device endpoint in SNS.
    - title: Notification title
    - message: Notification body text
    - data: Optional dict with custom data payload
    """

    response = sns.publish(
        TargetArn=endpoint_arn,
        Message=json.dumps(payload),
        MessageStructure='json'
    )

    return response
