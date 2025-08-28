#!/bin/bash

# Deploy landing page to S3 and invalidate CloudFront

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if AWS profile was provided
if [ -z "$1" ]; then
  echo "❌ Error: AWS profile name required"
  echo "Usage: ./landing-page/deploy.sh <aws-profile-name>"
  echo "Example: ./landing-page/deploy.sh my-sso-profile"
  exit 1
fi

AWS_PROFILE="$1"
S3_BUCKET="famefitapp.com"
CLOUDFRONT_DISTRIBUTION_ID="ECENS5RDQCV8U"

echo "🔐 Using AWS profile: $AWS_PROFILE"
echo "📁 Deploying from: $SCRIPT_DIR"

# Test AWS credentials
if ! aws sts get-caller-identity --profile "$AWS_PROFILE" > /dev/null 2>&1; then
  echo "❌ Error: Unable to authenticate with AWS profile '$AWS_PROFILE'"
  echo "Please ensure you're logged in via SSO:"
  echo "  aws sso login --profile $AWS_PROFILE"
  exit 1
fi

echo "🚀 Deploying landing page to S3..."

# CRITICAL: Only sync the landing-page directory contents
aws s3 sync "$SCRIPT_DIR" "s3://$S3_BUCKET/" \
  --profile "$AWS_PROFILE" \
  --exclude "*/.DS_Store" \
  --exclude ".DS_Store" \
  --exclude "*.sh" \
  --exclude "README.md" \
  --exclude "bucket-policy.json" \
  --exclude ".git/*" \
  --delete \
  --cache-control "public, max-age=3600"

echo "✅ Files synced to S3"

# Create CloudFront invalidation
echo "🔄 Creating CloudFront invalidation for distribution: $CLOUDFRONT_DISTRIBUTION_ID"

INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --profile "$AWS_PROFILE" \
  --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
  --paths "/*" \
  --query "Invalidation.Id" \
  --output text)

echo "✅ CloudFront invalidation created: $INVALIDATION_ID"
echo "Note: Invalidation typically takes 5-10 minutes to complete"

echo "🎉 Deployment complete!"
echo "Visit: https://$S3_BUCKET"