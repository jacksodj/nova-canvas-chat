#!/bin/bash
#
# Generate LiteLLM configuration for all available Bedrock models
# This script discovers active inference profiles and foundation models
#

set -e

REGION=${1:-us-east-1}
OUTPUT_FILE=${2:-bedrock-models-generated.yaml}

echo "🔍 Discovering Bedrock models in region: $REGION"
echo ""

# Check if AWS CLI and jq are installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed"
    exit 1
fi

echo "📋 Fetching active inference profiles..."
aws bedrock list-inference-profiles --region $REGION | \
  jq -r '.inferenceProfileSummaries[] |
    select(.status=="ACTIVE") |
    "- model_name: \"\(.inferenceProfileName)\"\n  litellm_params:\n    model: bedrock/\(.inferenceProfileId)\n    aws_region_name: '${REGION}'\n"' \
  > /tmp/bedrock-models.yaml

echo "📋 Fetching active foundation models (text, streaming, on-demand)..."
aws bedrock list-foundation-models --region $REGION | \
  jq -r '.modelSummaries[] |
    select(
      .modelLifecycle.status == "ACTIVE" and
      (.responseStreamingSupported == true) and
      (.inferenceTypesSupported | contains(["ON_DEMAND"])) and
      (.inputModalities | contains(["TEXT"])) and
      (.outputModalities | contains(["TEXT"]))
    ) |
    "- model_name: \"\(.modelName)\"\n  litellm_params:\n    model: bedrock/\(.modelId)\n    aws_region_name: '${REGION}'\n    stream: true\n"' \
  >> /tmp/bedrock-models.yaml

# Add LiteLLM settings
cat > $OUTPUT_FILE <<EOF
# Auto-generated Bedrock models configuration
# Region: $REGION
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

model_list:
EOF

cat /tmp/bedrock-models.yaml >> $OUTPUT_FILE

cat >> $OUTPUT_FILE <<EOF

litellm_settings:
  drop_params: true
  set_verbose: true
EOF

rm /tmp/bedrock-models.yaml

echo ""
echo "✅ Configuration generated: $OUTPUT_FILE"
echo ""
echo "📊 Model count:"
grep -c "model_name:" $OUTPUT_FILE || echo "0"
echo ""
echo "To use this configuration:"
echo "  cp $OUTPUT_FILE litellm-config.yaml"
echo "  docker compose restart litellm"
