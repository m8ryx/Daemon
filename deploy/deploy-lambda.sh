#!/bin/bash
# Deploy MCP API Lambda function

set -e

# Load environment variables
if [ -f "$(dirname "$0")/../.env" ]; then
  export $(grep -v '^#' "$(dirname "$0")/../.env" | xargs)
fi

FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-daemon-mcp}"
REGION="${AWS_REGION:-us-west-2}"
ROLE_NAME="${LAMBDA_ROLE_NAME:-daemon-mcp-role}"

echo "🚀 Deploying Daemon MCP Lambda..."

# Build daemon.md from sections first
cd "$(dirname "$0")/.."
echo "📦 Building daemon.md from sections..."
make
if [ $? -ne 0 ]; then
  echo "❌ Failed to build daemon.md"
  exit 1
fi

cd lambda

# Build and package Lambda
echo "📦 Building Lambda function..."
bun install
bun run build

# Copy necessary files to dist
cp package.json dist/
cp ../public/daemon.md dist/

# Create deployment package
cd dist
zip -r ../lambda.zip .
cd ..

echo "✅ Lambda package created: lambda/lambda.zip"

# Check if IAM role exists
echo "🔐 Checking IAM role..."
if ! aws iam get-role --role-name ${ROLE_NAME} 2>/dev/null; then
  echo "Creating IAM role..."

  # Create trust policy
  cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  # Create role
  aws iam create-role \
    --role-name ${ROLE_NAME} \
    --assume-role-policy-document file:///tmp/trust-policy.json

  # Attach basic execution policy
  aws iam attach-role-policy \
    --role-name ${ROLE_NAME} \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  rm /tmp/trust-policy.json

  echo "⏳ Waiting for role to be ready..."
  sleep 10

  echo "✅ IAM role created"
fi

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name ${ROLE_NAME} --query 'Role.Arn' --output text)

# Check if function exists
if aws lambda get-function --function-name ${FUNCTION_NAME} 2>/dev/null; then
  echo "📝 Updating existing Lambda function..."
  aws lambda update-function-code \
    --function-name ${FUNCTION_NAME} \
    --zip-file fileb://lambda.zip \
    --region ${REGION}

  echo "✅ Lambda function updated"
else
  echo "🆕 Creating new Lambda function..."
  aws lambda create-function \
    --function-name ${FUNCTION_NAME} \
    --runtime nodejs20.x \
    --role ${ROLE_ARN} \
    --handler mcp-server.handler \
    --zip-file fileb://lambda.zip \
    --timeout 10 \
    --memory-size 256 \
    --region ${REGION}

  echo "✅ Lambda function created"
fi

# Get function ARN
FUNCTION_ARN=$(aws lambda get-function --function-name ${FUNCTION_NAME} --query 'Configuration.FunctionArn' --output text)

echo ""
echo "✅ Lambda deployed successfully!"
echo "📍 Function ARN: ${FUNCTION_ARN}"
echo ""
echo "🔗 Next steps:"
echo "1. Create API Gateway REST API"
echo "2. Create a resource and POST method"
echo "3. Set up Lambda integration"
echo "4. Enable CORS"
echo "5. Deploy API to a stage"
echo "6. Set up custom domain: mcp.daemon.rick.rezinas.com"
echo ""
echo "Or use the automated script: deploy/setup-api-gateway.sh"
