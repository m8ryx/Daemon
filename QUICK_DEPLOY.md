# Quick Deployment Guide

Fast reference for deploying your Daemon to AWS with **secure private S3 + CloudFront OAC**.

## One-Time Setup (Do First)

### 1. Request SSL Certificate
```bash
aws acm request-certificate \
  --domain-name daemon.rick.rezinas.com \
  --validation-method DNS \
  --region us-east-1
```

Then go to ACM console and add the DNS validation records. Wait for "Issued" status.

### 2. Request API SSL Certificate
```bash
aws acm request-certificate \
  --domain-name mcp.daemon.rick.rezinas.com \
  --validation-method DNS \
  --region us-west-2
```

Add DNS validation records and wait for "Issued" status.

---

## Deployment (Run These Scripts)

### Deploy Everything

```bash
# 1. Deploy static site to PRIVATE S3
./deploy/deploy-s3.sh

# 2. Set up CloudFront with Origin Access Control (OAC)
./deploy/setup-cloudfront.sh

# Wait 5-15 minutes for CloudFront to deploy...

# 3. Deploy Lambda function
./deploy/deploy-lambda.sh

# 4. Set up API Gateway
./deploy/setup-api-gateway.sh
```

### Update DNS

After CloudFront deploys, add these DNS records:

**Website:**
```
Type: CNAME
Name: daemon.rick.rezinas.com
Value: [CloudFront domain, e.g., d123abc.cloudfront.net]
```

**API:**
```
Type: CNAME
Name: mcp.daemon.rick.rezinas.com
Value: [API Gateway regional domain]
```

---

## Quick Test

### Test Website
```bash
curl https://daemon.rick.rezinas.com
```

### Test API
```bash
curl -X POST https://mcp.daemon.rick.rezinas.com \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
```

---

## Update Your Daemon

### Update Content (daemon.md)
```bash
# Edit your personal data
vim public/daemon.md

# Redeploy Lambda (includes new daemon.md)
./deploy/deploy-lambda.sh
```

### Update Website
```bash
# Make changes to components/pages
# Then redeploy
./deploy/deploy-s3.sh

# Optional: invalidate CloudFront cache for immediate updates
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[0]=='daemon.rick.rezinas.com'].Id" \
  --output text)

aws cloudfront create-invalidation \
  --distribution-id $DIST_ID \
  --paths "/*"
```

---

## Security Features ✅

- ✅ S3 bucket is PRIVATE (not publicly accessible)
- ✅ CloudFront uses OAC to authenticate with S3
- ✅ HTTPS enforced (HTTP redirects to HTTPS)
- ✅ S3 versioning enabled (can rollback)
- ✅ All public access blocked on S3

**Users can ONLY access via CloudFront, not S3 directly.**

---

## Cost Estimate

**Low traffic (< 100K requests/month):**
- First year (free tier): ~$0/month
- After free tier: ~$2-7/month

---

## Troubleshooting

**403 Forbidden on website:**
- Wait 5-15 minutes for CloudFront deployment
- Check CloudFront status: `aws cloudfront get-distribution --id [DIST_ID]`

**API not responding:**
- Check Lambda logs: `aws logs tail /aws/lambda/daemon-mcp --follow`
- Verify API Gateway is deployed

**Need help?** See full guide in `AWS_DEPLOYMENT.md`
