#!/bin/bash
# Set up API Gateway for Lambda function

set -e

# Load environment variables
if [ -f "$(dirname "$0")/../.env" ]; then
  export $(grep -v '^#' "$(dirname "$0")/../.env" | xargs)
fi

FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-daemon-mcp}"
API_NAME="${API_NAME:-daemon-mcp-api}"
REGION="${AWS_REGION:-us-west-2}"
STAGE_NAME="${API_STAGE_NAME:-prod}"

echo "🚀 Setting up API Gateway..."

# Get Lambda ARN
FUNCTION_ARN=$(aws lambda get-function --function-name ${FUNCTION_NAME} --query 'Configuration.FunctionArn' --output text --region ${REGION})
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Check if API exists
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id" --output text --region ${REGION})

if [ -z "$API_ID" ]; then
  echo "🆕 Creating API Gateway..."
  API_ID=$(aws apigateway create-rest-api \
    --name ${API_NAME} \
    --description "MCP API for Daemon" \
    --endpoint-configuration types=REGIONAL \
    --query 'id' \
    --output text \
    --region ${REGION})

  echo "✅ API created: ${API_ID}"
else
  echo "✅ API already exists: ${API_ID}"
fi

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id ${API_ID} \
  --query 'items[?path==`/`].id' \
  --output text \
  --region ${REGION})

# Create POST method if it doesn't exist
if ! aws apigateway get-method \
  --rest-api-id ${API_ID} \
  --resource-id ${ROOT_ID} \
  --http-method POST \
  --region ${REGION} 2>/dev/null; then

  echo "📝 Creating POST method..."

  aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${ROOT_ID} \
    --http-method POST \
    --authorization-type NONE \
    --region ${REGION}

  aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${ROOT_ID} \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${FUNCTION_ARN}/invocations" \
    --region ${REGION}

  echo "✅ POST method created"
fi

# Enable CORS
echo "🔐 Setting up CORS..."

# OPTIONS method for CORS preflight
if ! aws apigateway get-method \
  --rest-api-id ${API_ID} \
  --resource-id ${ROOT_ID} \
  --http-method OPTIONS \
  --region ${REGION} 2>/dev/null; then

  aws apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${ROOT_ID} \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region ${REGION}

  aws apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${ROOT_ID} \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
    --region ${REGION}

  aws apigateway put-method-response \
    --rest-api-id ${API_ID} \
    --resource-id ${ROOT_ID} \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers": false, "method.response.header.Access-Control-Allow-Methods": false, "method.response.header.Access-Control-Allow-Origin": false}' \
    --region ${REGION}

  aws apigateway put-integration-response \
    --rest-api-id ${API_ID} \
    --resource-id ${ROOT_ID} \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''", "method.response.header.Access-Control-Allow-Methods": "'\''POST,OPTIONS'\''", "method.response.header.Access-Control-Allow-Origin": "'\''*'\''"}' \
    --region ${REGION}

  echo "✅ CORS configured"
fi

# Grant API Gateway permission to invoke Lambda
echo "🔑 Granting API Gateway permissions..."
aws lambda add-permission \
  --function-name ${FUNCTION_NAME} \
  --statement-id apigateway-invoke-${API_ID} \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
  --region ${REGION} 2>/dev/null || echo "Permission already exists"

# Deploy API
echo "🚀 Deploying API to ${STAGE_NAME}..."
aws apigateway create-deployment \
  --rest-api-id ${API_ID} \
  --stage-name ${STAGE_NAME} \
  --region ${REGION}

# Get invoke URL
INVOKE_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}"

echo ""
echo "✅ API Gateway deployed successfully!"
echo "📍 Invoke URL: ${INVOKE_URL}"
echo ""
echo "🧪 Test the API:"
echo "curl -X POST ${INVOKE_URL} \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"jsonrpc\": \"2.0\", \"method\": \"tools/list\", \"id\": 1}'"
echo ""
echo "🔗 Next steps:"
echo "1. Set up custom domain: mcp.daemon.rick.rezinas.com"
echo "2. Create ACM certificate for the domain"
echo "3. Add custom domain mapping in API Gateway"
echo "4. Update DNS to point to API Gateway domain"
