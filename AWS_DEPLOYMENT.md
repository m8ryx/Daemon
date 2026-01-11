# AWS Deployment Guide

This guide walks you through deploying your Daemon to AWS using S3 + CloudFront + Lambda + API Gateway.

## Architecture

```
┌─────────────────────────────────────────────┐
│              CloudFront CDN                 │
│      (daemon.rick.rezinas.com)              │
│         + Origin Access Control             │
└──────────────┬──────────────────────────────┘
               │
               ↓ (OAC authenticated access)
┌──────────────────────────────────────────────┐
│         PRIVATE S3 Bucket                    │
│         (HTML, CSS, JS files)                │
│    🔒 No public access allowed               │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│          API Gateway REST API                │
│    (mcp.daemon.rick.rezinas.com)             │
└──────────────┬───────────────────────────────┘
               │
               ↓
┌──────────────────────────────────────────────┐
│         AWS Lambda Function                  │
│      (MCP JSON-RPC 2.0 Server)               │
│      Bundled with daemon.md                  │
└──────────────────────────────────────────────┘
```

**Security Model:**
- S3 bucket is PRIVATE (all public access blocked)
- CloudFront uses Origin Access Control (OAC) to authenticate with S3
- Only CloudFront can access the S3 bucket
- Users cannot bypass CloudFront to access S3 directly
- HTTPS enforced via CloudFront (HTTP redirects to HTTPS)

## Prerequisites

1. **AWS CLI** installed and configured:
   ```bash
   aws configure
   ```
   You'll need:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (recommended: `us-west-2`)

2. **AWS Account permissions**:
   - S3 bucket creation and management
   - CloudFront distribution creation
   - Lambda function deployment
   - API Gateway setup
   - IAM role creation

3. **Domain names** (via Route 53 or external registrar):
   - `daemon.rick.rezinas.com` - for the website
   - `mcp.daemon.rick.rezinas.com` - for the API

## Deployment Steps

### Step 1: Request SSL Certificate (One-Time Setup)

Before deploying, you need an SSL certificate in **us-east-1** (required for CloudFront):

```bash
aws acm request-certificate \
  --domain-name daemon.rick.rezinas.com \
  --validation-method DNS \
  --region us-east-1
```

**Then validate the certificate:**
1. Go to AWS Certificate Manager console (us-east-1 region)
2. Click on your certificate
3. Add the CNAME records to your DNS provider
4. Wait for validation (usually 5-30 minutes)

### Step 2: Deploy Static Website to Private S3

```bash
./deploy/deploy-s3.sh
```

This script will:
- Build the Astro static site (`dist/` folder)
- Create PRIVATE S3 bucket `daemon.rick.rezinas.com`
- Block ALL public access (secure by default)
- Enable versioning
- Upload all files with appropriate cache headers
- Output the bucket name

**Cost**: Free tier covers most usage (~$0-1/month for low traffic)

### Step 3: Set Up CloudFront with Origin Access Control

```bash
./deploy/setup-cloudfront.sh
```

This script will:
- Verify SSL certificate exists (from Step 1)
- Create Origin Access Control (OAC) for S3
- Create CloudFront distribution with:
  - OAC authentication to private S3
  - HTTPS enforcement (redirect HTTP to HTTPS)
  - Custom domain: daemon.rick.rezinas.com
  - Gzip compression enabled
  - SPA error handling (404 → index.html)
- Update S3 bucket policy to ONLY allow CloudFront access
- Output CloudFront domain name

**Wait 5-15 minutes** for CloudFront to deploy globally.

**Cost**: Free tier covers 1TB/month data transfer (~$1-5/month after)

### Step 4: Deploy Lambda Function

```bash
./deploy/deploy-lambda.sh
```

This script will:
- Build the TypeScript Lambda function
- Bundle `daemon.md` into the deployment package
- Create IAM role with Lambda execution permissions
- Deploy Lambda function `daemon-mcp`
- Output the Lambda ARN

**Cost**: Free tier covers 1M requests/month (~$0-1/month)

### Step 5: Set Up API Gateway

```bash
./deploy/setup-api-gateway.sh
```

This script will:
- Create REST API in API Gateway
- Set up POST method with Lambda integration
- Configure CORS (OPTIONS method)
- Grant API Gateway permission to invoke Lambda
- Deploy to `prod` stage
- Output the invoke URL

**Cost**: Free tier covers 1M requests/month (~$0/month for low traffic)

### Step 6: Update DNS for Website

After CloudFront is deployed (from Step 3), get the CloudFront domain:

```bash
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[0]=='daemon.rick.rezinas.com'].Id" \
  --output text)

aws cloudfront get-distribution \
  --id $DIST_ID \
  --query 'Distribution.DomainName' \
  --output text
```

**Create DNS record** (in Route 53 or your DNS provider):
- Type: CNAME
- Name: daemon.rick.rezinas.com
- Value: [CloudFront domain from above, e.g., d123abc.cloudfront.net]
- TTL: 300

### Step 7: Set Up Custom Domain for API (Manual)

1. **Request SSL Certificate for API** (in your API region):
   ```bash
   aws acm request-certificate \
     --domain-name mcp.daemon.rick.rezinas.com \
     --validation-method DNS \
     --region us-west-2
   ```

2. **Validate the certificate** (add DNS CNAME records)

3. **Create Custom Domain in API Gateway**:
   ```bash
   aws apigateway create-domain-name \
     --domain-name mcp.daemon.rick.rezinas.com \
     --certificate-arn <your-certificate-arn> \
     --region us-west-2
   ```

4. **Create Base Path Mapping**:
   ```bash
   API_ID=$(aws apigateway get-rest-apis --query "items[?name=='daemon-mcp-api'].id" --output text --region us-west-2)

   aws apigateway create-base-path-mapping \
     --domain-name mcp.daemon.rick.rezinas.com \
     --rest-api-id $API_ID \
     --stage prod \
     --region us-west-2
   ```

5. **Get Target Domain Name**:
   ```bash
   aws apigateway get-domain-name \
     --domain-name mcp.daemon.rick.rezinas.com \
     --query 'regionalDomainName' \
     --output text \
     --region us-west-2
   ```

6. **Update DNS**:
   - Create CNAME record: `mcp.daemon.rick.rezinas.com` → Regional API Gateway domain

## Testing

### Test the Static Site

**Note:** With private S3, you CANNOT access the bucket directly. You must use CloudFront.

After CloudFront deployment (Step 3), test using the CloudFront domain:

```bash
# Get CloudFront domain
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[0]=='daemon.rick.rezinas.com'].Id" \
  --output text)

DIST_DOMAIN=$(aws cloudfront get-distribution \
  --id $DIST_ID \
  --query 'Distribution.DomainName' \
  --output text)

# Test via CloudFront (before DNS is set up)
curl https://$DIST_DOMAIN

# After DNS is configured
curl https://daemon.rick.rezinas.com
```

### Test the MCP API

After API Gateway deployment:
```bash
# Using the API Gateway invoke URL
INVOKE_URL=$(aws apigateway get-rest-apis --query "items[?name=='daemon-mcp-api'].id" --output text)
INVOKE_URL="https://${INVOKE_URL}.execute-api.us-west-2.amazonaws.com/prod"

# Test tools/list
curl -X POST $INVOKE_URL \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'

# Test get_about
curl -X POST $INVOKE_URL \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "get_about"}, "id": 2}'

# Test get_all
curl -X POST $INVOKE_URL \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "get_all"}, "id": 3}'
```

After custom domain setup:
```bash
curl -X POST https://mcp.daemon.rick.rezinas.com \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
```

## Updating Your Daemon

### Update Personal Data

1. Edit `public/daemon.md` with your new information
2. Redeploy Lambda:
   ```bash
   ./deploy/deploy-lambda.sh
   ```

### Update Website

1. Make changes to components/pages
2. Redeploy to S3:
   ```bash
   ./deploy/deploy-s3.sh
   ```
3. Invalidate CloudFront cache (optional, for immediate updates):
   ```bash
   DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Aliases.Items[0]=='daemon.rick.rezinas.com'].Id" --output text)
   aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"
   ```

## Cost Estimate

For low-moderate traffic (< 100K requests/month):

| Service | Free Tier | After Free Tier |
|---------|-----------|-----------------|
| S3 | 5GB storage, 20K GET, 2K PUT | ~$0.50/month |
| CloudFront | 1TB/month transfer | ~$1-5/month |
| Lambda | 1M requests, 400K GB-seconds | ~$0-1/month |
| API Gateway | 1M requests | ~$0/month |
| Route 53 | N/A | $0.50/hosted zone/month |
| **Total** | **~$0/month (first year)** | **~$2-7/month** |

## Troubleshooting

### Static site shows 403 Forbidden
- Check CloudFront distribution status (must be "Deployed")
- Verify S3 bucket policy allows CloudFront OAC access
- Check that you're accessing via CloudFront, not S3 directly
- Wait 5-15 minutes after CloudFront creation for global deployment

### API returns CORS errors
- Verify OPTIONS method is configured
- Check CORS headers in Lambda response

### Lambda function fails
- Check CloudWatch Logs:
  ```bash
  aws logs tail /aws/lambda/daemon-mcp --follow
  ```
- Verify daemon.md is bundled in deployment package

### CloudFront shows old content
- Invalidate the cache (see "Updating Your Daemon" above)
- Wait 5-15 minutes for propagation

## Security Notes

- ✅ S3 bucket is PRIVATE (all public access blocked)
- ✅ CloudFront uses Origin Access Control (OAC) to authenticate with S3
- ✅ Only CloudFront can access the S3 bucket - direct S3 access is blocked
- ✅ HTTPS enforced via CloudFront (HTTP redirects to HTTPS)
- ✅ S3 bucket versioning enabled (can rollback changes)
- ⚠️ API has no authentication (public MCP endpoint by design)
- ⚠️ No sensitive data should be in daemon.md (it's publicly accessible)

## Next Steps

After deployment:
1. Test all MCP endpoints
2. Verify website loads correctly
3. Update your TELOS missions in daemon.md
4. Share your daemon URL with AI assistants
5. Monitor AWS costs in the billing console
