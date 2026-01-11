#!/bin/bash
# Deploy static site to PRIVATE S3 bucket (CloudFront will provide access)

set -e

BUCKET_NAME="daemon.rick.rezinas.com"
REGION="us-west-2"

echo "🚀 Deploying Daemon to AWS (Private S3 + CloudFront)..."

# Build the static site
echo "📦 Building static site..."
cd "$(dirname "$0")/.."
bun run build

# Create S3 bucket if it doesn't exist
echo "🪣 Setting up PRIVATE S3 bucket..."
if ! aws s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
  # Create bucket
  aws s3 mb "s3://${BUCKET_NAME}" --region ${REGION}

  # Block all public access (secure by default)
  aws s3api put-public-access-block \
    --bucket ${BUCKET_NAME} \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  # Enable versioning (optional but recommended)
  aws s3api put-bucket-versioning \
    --bucket ${BUCKET_NAME} \
    --versioning-configuration Status=Enabled

  echo "✅ Private S3 bucket created"
else
  echo "✅ S3 bucket already exists"
fi

# Sync dist to S3
echo "📤 Uploading files to private S3 bucket..."
aws s3 sync dist/ "s3://${BUCKET_NAME}" \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "*.html" \
  --exclude "daemon.md"

# Upload HTML files with no-cache
aws s3 sync dist/ "s3://${BUCKET_NAME}" \
  --cache-control "public, max-age=0, must-revalidate" \
  --exclude "*" \
  --include "*.html"

echo ""
echo "✅ Static site deployed to PRIVATE S3 bucket!"
echo "🔒 Bucket is NOT publicly accessible (secure)"
echo "📍 Bucket: s3://${BUCKET_NAME}"
echo ""
echo "🔗 Next steps:"
echo "1. Run deploy/setup-cloudfront.sh to create CloudFront distribution with OAC"
echo "2. CloudFront will be configured to access this private bucket securely"
echo "3. Deploy the Lambda function (run deploy/deploy-lambda.sh)"
