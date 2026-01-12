# Daemon Deployment Scripts

## Setup

1. **Copy `.env.example` to `.env`** in the project root:
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env`** with your actual values:
   - AWS account ID and region
   - Domain names
   - CloudFront distribution ID
   - Lambda function names

## Environment Variables

All deployment scripts automatically load configuration from `.env`:

- `AWS_REGION` - AWS region (default: us-west-2)
- `AWS_ACCOUNT_ID` - Your AWS account ID
- `AWS_PROFILE` - AWS CLI profile to use
- `DOMAIN_NAME` - Your daemon domain (e.g., daemon.yourdomain.com)
- `API_DOMAIN` - Your API domain (e.g., mcp.daemon.yourdomain.com)
- `BUCKET_NAME` - S3 bucket name (usually same as DOMAIN_NAME)
- `CLOUDFRONT_DISTRIBUTION_ID` - CloudFront distribution ID
- `LAMBDA_FUNCTION_NAME` - Lambda function name (default: daemon-mcp)
- `LAMBDA_ROLE_NAME` - IAM role name (default: daemon-mcp-role)
- `API_NAME` - API Gateway name (default: daemon-mcp-api)
- `API_STAGE_NAME` - API stage (default: prod)

## Deployment Scripts

### `deploy-s3.sh`
Builds and deploys the static website to S3.

```bash
./deploy/deploy-s3.sh
```

### `deploy-lambda.sh`
Builds and deploys the Lambda MCP API function.

```bash
./deploy/deploy-lambda.sh
```

### `setup-cloudfront.sh`
Sets up CloudFront distribution with Origin Access Control (OAC).
Only needs to be run once during initial setup.

```bash
./deploy/setup-cloudfront.sh
```

### `setup-api-gateway.sh`
Sets up API Gateway for the Lambda function.
Only needs to be run once during initial setup.

```bash
./deploy/setup-api-gateway.sh
```

### `invalidate-cloudfront.sh`
Invalidates CloudFront cache to refresh content immediately.

```bash
./deploy/invalidate-cloudfront.sh
```

## Makefile Integration

You can also deploy using make commands:

```bash
# Deploy everything (website + API)
make deploy

# Deploy just the website
make deploy-web

# Deploy just the Lambda API
make deploy-api
```

## Security

- `.env` is excluded from git via `.gitignore`
- Never commit your `.env` file
- Share `.env.example` as a template for others
