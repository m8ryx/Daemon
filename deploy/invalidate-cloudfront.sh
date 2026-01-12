#!/bin/bash
# Invalidate CloudFront cache

set -e

# Load environment variables
if [ -f "$(dirname "$0")/../.env" ]; then
  export $(grep -v '^#' "$(dirname "$0")/../.env" | xargs)
fi

if [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
  echo "❌ CLOUDFRONT_DISTRIBUTION_ID not set in .env"
  exit 1
fi

echo "🔄 Invalidating CloudFront cache..."
echo "Distribution: ${CLOUDFRONT_DISTRIBUTION_ID}"

aws cloudfront create-invalidation \
  --distribution-id "${CLOUDFRONT_DISTRIBUTION_ID}" \
  --paths "/*"

echo "✅ Cache invalidation in progress"
