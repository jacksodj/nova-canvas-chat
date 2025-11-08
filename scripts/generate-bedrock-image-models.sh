#!/bin/bash
#
# Generate LiteLLM configuration for Bedrock image generation models
# This script discovers active image generation models
#

set -e

REGION=${1:-us-east-1}
OUTPUT_FILE=${2:-bedrock-image-models-generated.yaml}

echo "🔍 Discovering Bedrock image generation models in region: $REGION"
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

echo "📋 Fetching active image generation models..."
aws bedrock list-foundation-models --region $REGION | \
  jq -r '.modelSummaries[] |
    select(
      .modelLifecycle.status == "ACTIVE" and
      (.inferenceTypesSupported | contains(["ON_DEMAND"])) and
      (.inputModalities | contains(["TEXT"])) and
      (.outputModalities | contains(["IMAGE"]))
    ) |
    "- model_name: \"\(.modelName)\"\n  litellm_params:\n    model: bedrock/\(.modelId)\n    aws_region_name: '${REGION}'\n"' \
  > /tmp/bedrock-image-models.yaml

# Create the config file
cat > $OUTPUT_FILE <<EOF
# Auto-generated Bedrock image generation models configuration
# Region: $REGION
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

model_list:
EOF

cat /tmp/bedrock-image-models.yaml >> $OUTPUT_FILE

cat >> $OUTPUT_FILE <<EOF

litellm_settings:
  drop_params: true
  set_verbose: true
EOF

rm /tmp/bedrock-image-models.yaml

echo ""
echo "✅ Configuration generated: $OUTPUT_FILE"
echo ""
echo "📊 Image model count:"
grep -c "model_name:" $OUTPUT_FILE || echo "0"
echo ""
echo "Models found:"
grep "model_name:" $OUTPUT_FILE | sed 's/.*model_name: "\(.*\)"/  - \1/'
echo ""
echo "To use this configuration:"
echo "  cp $OUTPUT_FILE litellm-image-config.yaml"
echo "  docker compose restart litellm-image"
