#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AWS Bedrock Model Discovery Tool${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get region
REGION=${1:-us-east-1}
echo -e "${GREEN}Using region: ${REGION}${NC}"
echo ""

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ AWS Account: ${ACCOUNT_ID}${NC}"
echo ""

# Function to format ARN for LiteLLM
format_for_litellm() {
    local arn=$1
    local model_name=$2
    echo ""
    echo -e "${YELLOW}Add to LiteLLM configuration:${NC}"
    echo "----------------------------------------"
    cat <<EOF
  - model_name: ${model_name}
    litellm_params:
      model: bedrock/${arn}
      aws_region_name: ${REGION}
EOF
    echo "----------------------------------------"
}

# 1. Check Foundation Models (including Nova Canvas)
echo -e "${BLUE}📋 Available Foundation Models (Nova family):${NC}"
echo "=========================================="

FOUNDATION_MODELS=$(aws bedrock list-foundation-models \
    --region ${REGION} \
    --query 'modelSummaries[?contains(modelId, `nova`)]' \
    --output json 2>/dev/null || echo "[]")

if [ "$FOUNDATION_MODELS" = "[]" ]; then
    echo -e "${YELLOW}⚠️  No Nova models found. Check model access in Bedrock console.${NC}"
else
    echo "$FOUNDATION_MODELS" | jq -r '.[] | "✅ \(.modelName)\n   ID: \(.modelId)\n   Status: \(.modelLifecycle.status // "ACTIVE")\n"'
fi
echo ""

# 2. Check Custom/Fine-tuned Models
echo -e "${BLUE}🎨 Fine-tuned / Custom Models:${NC}"
echo "=========================================="

CUSTOM_MODELS=$(aws bedrock list-custom-models \
    --region ${REGION} \
    --output json 2>/dev/null || echo '{"modelSummaries":[]}')

CUSTOM_COUNT=$(echo "$CUSTOM_MODELS" | jq '.modelSummaries | length')

if [ "$CUSTOM_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}ℹ️  No custom models found${NC}"
    echo ""
    echo "To create a custom model:"
    echo "  1. Go to AWS Bedrock console"
    echo "  2. Navigate to Custom models"
    echo "  3. Create model customization job"
    echo "  4. Wait for training to complete"
else
    echo "$CUSTOM_MODELS" | jq -r '.modelSummaries[] | "✅ \(.modelName)\n   ARN: \(.modelArn)\n   Base: \(.baseModelArn)\n   Status: \(.jobStatus // "ACTIVE")\n"'

    # Show how to add to LiteLLM
    FIRST_CUSTOM=$(echo "$CUSTOM_MODELS" | jq -r '.modelSummaries[0] | @json')
    if [ "$FIRST_CUSTOM" != "null" ]; then
        MODEL_ARN=$(echo "$FIRST_CUSTOM" | jq -r '.modelArn')
        MODEL_NAME=$(echo "$FIRST_CUSTOM" | jq -r '.modelName')
        format_for_litellm "$MODEL_ARN" "custom-$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    fi
fi
echo ""

# 3. Check Provisioned Throughput
echo -e "${BLUE}⚡ Provisioned Throughput Models:${NC}"
echo "=========================================="

PROVISIONED=$(aws bedrock list-provisioned-model-throughputs \
    --region ${REGION} \
    --output json 2>/dev/null || echo '{"provisionedModelSummaries":[]}')

PROV_COUNT=$(echo "$PROVISIONED" | jq '.provisionedModelSummaries | length')

if [ "$PROV_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}ℹ️  No provisioned throughput found${NC}"
    echo ""
    echo "To create provisioned throughput:"
    echo "  aws bedrock create-provisioned-model-throughput \\"
    echo "    --provisioned-model-name 'my-nova-canvas-provisioned' \\"
    echo "    --model-id 'amazon.nova-canvas-v1:0' \\"
    echo "    --model-units 1 \\"
    echo "    --commitment-duration 'OneMonth' \\"
    echo "    --region ${REGION}"
else
    echo "$PROVISIONED" | jq -r '.provisionedModelSummaries[] |
        "✅ \(.provisionedModelName)\n" +
        "   ARN: \(.provisionedModelArn)\n" +
        "   Base Model: \(.modelId // .modelArn)\n" +
        "   Units: \(.modelUnits)\n" +
        "   Status: \(.status)\n" +
        "   Commitment: \(.commitmentDuration // "N/A")\n"'

    # Show how to add to LiteLLM for each provisioned model
    echo "$PROVISIONED" | jq -r '.provisionedModelSummaries[] | @json' | while read -r model; do
        PROV_ARN=$(echo "$model" | jq -r '.provisionedModelArn')
        PROV_NAME=$(echo "$model" | jq -r '.provisionedModelName')
        PROV_STATUS=$(echo "$model" | jq -r '.status')

        if [ "$PROV_STATUS" = "InService" ]; then
            format_for_litellm "$PROV_ARN" "$(echo $PROV_NAME | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
        else
            echo -e "${YELLOW}⚠️  Model '$PROV_NAME' is not yet InService (Status: $PROV_STATUS)${NC}"
        fi
    done
fi
echo ""

# 4. Generate complete LiteLLM config
echo -e "${BLUE}📝 Complete LiteLLM Configuration:${NC}"
echo "=========================================="

CONFIG_FILE="litellm-config-generated.yaml"

cat > "$CONFIG_FILE" <<EOF
# Auto-generated LiteLLM configuration
# Generated: $(date)
# Region: ${REGION}
# Account: ${ACCOUNT_ID}

model_list:
  # Standard on-demand models
  - model_name: nova-canvas
    litellm_params:
      model: bedrock/amazon.nova-canvas-v1:0
      aws_region_name: ${REGION}

  - model_name: claude-sonnet
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: ${REGION}
      stream: true

  - model_name: titan-image
    litellm_params:
      model: bedrock/amazon.titan-image-generator-v2:0
      aws_region_name: ${REGION}

EOF

# Add custom models
if [ "$CUSTOM_COUNT" -gt 0 ]; then
    echo "  # Fine-tuned / Custom models" >> "$CONFIG_FILE"
    echo "$CUSTOM_MODELS" | jq -r '.modelSummaries[] |
        "  - model_name: custom-" + (.modelName | ascii_downcase | gsub(" "; "-")) + "\n" +
        "    litellm_params:\n" +
        "      model: bedrock/" + .modelArn + "\n" +
        "      aws_region_name: '"${REGION}"'\n"' >> "$CONFIG_FILE"
fi

# Add provisioned models
if [ "$PROV_COUNT" -gt 0 ]; then
    echo "  # Provisioned throughput models" >> "$CONFIG_FILE"
    echo "$PROVISIONED" | jq -r '.provisionedModelSummaries[] |
        select(.status == "InService") |
        "  - model_name: " + (.provisionedModelName | ascii_downcase | gsub(" "; "-")) + "\n" +
        "    litellm_params:\n" +
        "      model: bedrock/" + .provisionedModelArn + "\n" +
        "      aws_region_name: '"${REGION}"'\n"' >> "$CONFIG_FILE"
fi

# Add settings
cat >> "$CONFIG_FILE" <<EOF

litellm_settings:
  drop_params: true
  set_verbose: false
EOF

echo -e "${GREEN}✅ Generated configuration file: ${CONFIG_FILE}${NC}"
echo ""
echo "To use this configuration:"
echo "  1. Copy to your deployment: cp ${CONFIG_FILE} litellm-config.yaml"
echo "  2. Update CloudFormation parameter: ProvisionedModelArn=<ARN>"
echo "  3. Deploy stack with new configuration"
echo ""

# 5. Quick deployment commands
echo -e "${BLUE}🚀 Quick Deployment Commands:${NC}"
echo "=========================================="

if [ "$PROV_COUNT" -gt 0 ]; then
    FIRST_PROV_ARN=$(echo "$PROVISIONED" | jq -r '.provisionedModelSummaries[0].provisionedModelArn')

    echo "Update CloudFormation stack with provisioned model:"
    echo ""
    cat <<EOF
aws cloudformation update-stack \\
  --stack-name bedrock-image-chat \\
  --template-body file://bedrock-image-chat-stack.yaml \\
  --parameters \\
    ParameterKey=ProvisionedModelArn,ParameterValue=${FIRST_PROV_ARN} \\
    ParameterKey=ProjectName,UsePreviousValue=true \\
    ParameterKey=Environment,UsePreviousValue=true \\
    ParameterKey=DeploymentSize,UsePreviousValue=true \\
    ParameterKey=BedrockRegion,UsePreviousValue=true \\
    ParameterKey=EnabledModels,UsePreviousValue=true \\
    ParameterKey=ACMCertificateArn,UsePreviousValue=true \\
    ParameterKey=AllowedCIDR,UsePreviousValue=true \\
  --capabilities CAPABILITY_NAMED_IAM \\
  --region ${REGION}
EOF
    echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Model discovery complete!${NC}"
echo -e "${GREEN}========================================${NC}"
