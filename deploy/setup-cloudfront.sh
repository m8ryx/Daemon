#!/bin/bash
# Set up CloudFront distribution with Origin Access Control (OAC)

set -e

BUCKET_NAME="daemon.rick.rezinas.com"
DOMAIN_NAME="daemon.rick.rezinas.com"
REGION="us-west-2"

echo "🚀 Setting up CloudFront with Origin Access Control..."

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Check if ACM certificate exists in us-east-1 (required for CloudFront)
echo "🔐 Checking for SSL certificate in us-east-1..."
CERT_ARN=$(aws acm list-certificates \
  --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='${DOMAIN_NAME}'].CertificateArn" \
  --output text)

if [ -z "$CERT_ARN" ]; then
  echo "❌ No SSL certificate found for ${DOMAIN_NAME} in us-east-1"
  echo ""
  echo "Please request a certificate first:"
  echo ""
  echo "aws acm request-certificate \\"
  echo "  --domain-name ${DOMAIN_NAME} \\"
  echo "  --validation-method DNS \\"
  echo "  --region us-east-1"
  echo ""
  echo "Then validate it by adding the DNS CNAME records shown in ACM console."
  echo "Re-run this script once the certificate is validated."
  exit 1
fi

echo "✅ Found SSL certificate: ${CERT_ARN}"

# Create Origin Access Control (OAC) if it doesn't exist
echo "🔑 Setting up Origin Access Control..."
OAC_NAME="daemon-s3-oac"
OAC_ID=$(aws cloudfront list-origin-access-controls \
  --query "OriginAccessControlList.Items[?Name=='${OAC_NAME}'].Id" \
  --output text 2>/dev/null || echo "")

# AWS CLI returns "None" as a string when query finds nothing
if [ -z "$OAC_ID" ] || [ "$OAC_ID" = "None" ]; then
  echo "Creating new OAC..."

  cat > /tmp/oac-config.json <<EOF
{
  "Name": "${OAC_NAME}",
  "Description": "Origin Access Control for Daemon S3 bucket",
  "SigningProtocol": "sigv4",
  "SigningBehavior": "always",
  "OriginAccessControlOriginType": "s3"
}
EOF

  OAC_ID=$(aws cloudfront create-origin-access-control \
    --origin-access-control-config file:///tmp/oac-config.json \
    --query 'OriginAccessControl.Id' \
    --output text)

  rm /tmp/oac-config.json
  echo "✅ Created OAC: ${OAC_ID}"

  # Wait a moment for propagation
  echo "⏳ Waiting for OAC to propagate..."
  sleep 3
else
  echo "✅ OAC already exists: ${OAC_ID}"
fi

# Verify OAC ID is not empty
if [ -z "$OAC_ID" ]; then
  echo "❌ Error: OAC ID is empty. Failed to create or retrieve OAC."
  exit 1
fi

echo "🔍 Verifying OAC exists..."
echo "   OAC_ID value: '${OAC_ID}'"
if ! aws cloudfront get-origin-access-control --id "${OAC_ID}" 2>&1 | grep -q '"Id"'; then
  echo "❌ Error: Cannot verify OAC with ID ${OAC_ID}"
  echo "Attempting to retrieve OAC details for debugging:"
  aws cloudfront get-origin-access-control --id "${OAC_ID}" 2>&1 || true
  exit 1
fi
echo "✅ OAC verified: ${OAC_ID}"

# Create CloudFront distribution
echo "☁️  Creating CloudFront distribution..."
echo "   Using OAC ID: ${OAC_ID}"

# Generate a unique caller reference
CALLER_REF="daemon-$(date +%s)"

cat > /tmp/cf-config.json <<EOF
{
  "CallerReference": "${CALLER_REF}",
  "Comment": "Daemon personal API website",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Aliases": {
    "Quantity": 1,
    "Items": ["${DOMAIN_NAME}"]
  },
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-${BUCKET_NAME}",
        "DomainName": "${BUCKET_NAME}.s3.${REGION}.amazonaws.com",
        "OriginAccessControlId": "${OAC_ID}",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        },
        "ConnectionAttempts": 3,
        "ConnectionTimeout": 10
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-${BUCKET_NAME}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    }
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "${CERT_ARN}",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "PriceClass": "PriceClass_100",
  "HttpVersion": "http2and3"
}
EOF

# Check if distribution already exists
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[0]=='${DOMAIN_NAME}'].Id" \
  --output text 2>/dev/null || echo "")

if [ -z "$DIST_ID" ]; then
  echo "Creating new CloudFront distribution..."
  DIST_ID=$(aws cloudfront create-distribution \
    --distribution-config file:///tmp/cf-config.json \
    --query 'Distribution.Id' \
    --output text)

  echo "✅ Created CloudFront distribution: ${DIST_ID}"
else
  echo "⚠️  CloudFront distribution already exists: ${DIST_ID}"
  echo "Skipping distribution creation."
fi

rm /tmp/cf-config.json

# Get distribution domain name
DIST_DOMAIN=$(aws cloudfront get-distribution \
  --id ${DIST_ID} \
  --query 'Distribution.DomainName' \
  --output text)

# Update S3 bucket policy to allow ONLY CloudFront OAC access
echo "🔒 Updating S3 bucket policy for CloudFront OAC access..."

cat > /tmp/bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::${AWS_ACCOUNT_ID}:distribution/${DIST_ID}"
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket ${BUCKET_NAME} \
  --policy file:///tmp/bucket-policy.json

rm /tmp/bucket-policy.json

echo ""
echo "✅ CloudFront distribution configured with OAC!"
echo ""
echo "📍 Distribution ID: ${DIST_ID}"
echo "📍 CloudFront Domain: ${DIST_DOMAIN}"
echo ""
echo "🔒 Security:"
echo "  - S3 bucket is PRIVATE (not publicly accessible)"
echo "  - Only CloudFront can access the bucket via OAC"
echo "  - HTTPS enforced (HTTP redirects to HTTPS)"
echo ""
echo "🔗 Next steps:"
echo "1. Wait for CloudFront deployment (5-15 minutes)"
echo "   Check status: aws cloudfront get-distribution --id ${DIST_ID} --query 'Distribution.Status'"
echo ""
echo "2. Update DNS to point to CloudFront:"
echo "   CNAME: ${DOMAIN_NAME} → ${DIST_DOMAIN}"
echo ""
echo "3. Test the site:"
echo "   https://${DOMAIN_NAME}"
echo ""
echo "4. Deploy the Lambda function (run deploy/deploy-lambda.sh)"
