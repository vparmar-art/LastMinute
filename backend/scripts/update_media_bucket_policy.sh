#!/bin/bash
# Update the media S3 bucket policy so partner uploads work.
# Usage: ./scripts/update_media_bucket_policy.sh <bucket-name> <account-id> <prefix>

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <bucket-name> <account-id> [prefix]"
  exit 1
fi

BUCKET="$1"
ACCOUNT_ID="$2"
PREFIX="${3:-documents/selfies/}"

TASK_ROLE="arn:aws:iam::${ACCOUNT_ID}:role/lastminute-us-east-1-ecs-task-exec"
ACCOUNT_ROOT="arn:aws:iam::${ACCOUNT_ID}:root"

cat <<EOF > /tmp/media-bucket-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAccountListPrefix",
      "Effect": "Allow",
      "Principal": {
        "AWS": ["${TASK_ROLE}", "${ACCOUNT_ROOT}"]
      },
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${BUCKET}",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["${PREFIX}*"]
        }
      }
    },
    {
      "Sid": "AllowAccountObjects",
      "Effect": "Allow",
      "Principal": {
        "AWS": ["${TASK_ROLE}", "${ACCOUNT_ROOT}"]
      },
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::${BUCKET}/${PREFIX}*"
    }
  ]
}
EOF

echo "Updating bucket policy for ${BUCKET}..."
aws s3api put-bucket-policy --bucket "${BUCKET}" --policy file:///tmp/media-bucket-policy.json
echo "Done."

