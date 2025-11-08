# Bedrock Model Discovery Scripts

These scripts automatically discover and configure all available Bedrock models in your AWS account.

## Scripts

### `generate-bedrock-models.sh`

Generates LiteLLM configuration for **text/chat models** (for the main LiteLLM instance on port 4000).

**Discovers:**
- Active inference profiles (recommended - with `us.` prefix for load balancing)
- Active foundation models that support:
  - Response streaming
  - On-demand inference
  - Text input and output

**Usage:**
```bash
./scripts/generate-bedrock-models.sh [region] [output-file]

# Examples:
./scripts/generate-bedrock-models.sh us-east-1 litellm-config.yaml
./scripts/generate-bedrock-models.sh us-west-2
./scripts/generate-bedrock-models.sh  # Uses defaults: us-east-1, bedrock-models-generated.yaml
```

### `generate-bedrock-image-models.sh`

Generates LiteLLM configuration for **image generation models** (for the image LiteLLM instance on port 4100).

**Discovers:**
- Active foundation models that support:
  - On-demand inference
  - Text input
  - Image output

**Usage:**
```bash
./scripts/generate-bedrock-image-models.sh [region] [output-file]

# Examples:
./scripts/generate-bedrock-image-models.sh us-east-1 litellm-image-config.yaml
./scripts/generate-bedrock-image-models.sh us-west-2
./scripts/generate-bedrock-image-models.sh  # Uses defaults: us-east-1, bedrock-image-models-generated.yaml
```

## Prerequisites

- AWS CLI installed and configured
- `jq` installed (for JSON processing)
- AWS credentials with permissions to:
  - `bedrock:ListInferenceProfiles`
  - `bedrock:ListFoundationModels`

## Workflow

### Full Setup

```bash
# 1. Generate configurations for both chat and image models
./scripts/generate-bedrock-models.sh us-east-1 litellm-config.yaml
./scripts/generate-bedrock-image-models.sh us-east-1 litellm-image-config.yaml

# 2. Review the generated configurations
cat litellm-config.yaml
cat litellm-image-config.yaml

# 3. Restart services to apply
docker compose restart litellm litellm-image
```

### Update Existing Setup

```bash
# Regenerate configurations
./scripts/generate-bedrock-models.sh us-east-1
./scripts/generate-bedrock-image-models.sh us-east-1

# Review differences
diff litellm-config.yaml bedrock-models-generated.yaml
diff litellm-image-config.yaml bedrock-image-models-generated.yaml

# Apply if satisfied
cp bedrock-models-generated.yaml litellm-config.yaml
cp bedrock-image-models-generated.yaml litellm-image-config.yaml

docker compose restart litellm litellm-image
```

## What Gets Discovered

### Text/Chat Models (litellm-config.yaml)

Typical models discovered:
- Claude Sonnet 4, 4.5 (via inference profiles: `us.anthropic.claude-sonnet-4-...`)
- Claude Haiku, Opus variants
- Amazon Titan Text models
- Mistral models
- Meta Llama models
- AI21 Jurassic models

### Image Generation Models (litellm-image-config.yaml)

Typical models discovered:
- Amazon Nova Canvas (`amazon.nova-canvas-v1:0`)
- Stability AI Stable Diffusion models
  - `stability.sd3-5-large-v1:0`
  - `stability.stable-image-ultra-v1:1`
  - `stability.stable-image-core-v1:0`

## Manual Customization

After generation, you can manually edit the configs to:

1. **Remove unwanted models:**
   ```yaml
   # Delete model entries you don't want to expose
   ```

2. **Add custom names:**
   ```yaml
   - model_name: "My Custom Claude"  # Change display name
     litellm_params:
       model: bedrock/us.anthropic.claude-sonnet-4-20250514-v1:0
   ```

3. **Add API keys or other params:**
   ```yaml
   litellm_params:
     model: bedrock/us.anthropic.claude-sonnet-4-20250514-v1:0
     api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
     temperature: 0.7  # Custom defaults
   ```

4. **Configure streaming:**
   ```yaml
   # Image models should NOT stream
   - model_name: nova-canvas
     litellm_params:
       model: bedrock/amazon.nova-canvas-v1:0
       stream: false  # Add this for image models
   ```

## Troubleshooting

### No models found

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check region
aws bedrock list-foundation-models --region us-east-1

# Check model access in Bedrock console
# https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess
```

### Permission errors

Ensure your IAM user/role has:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:ListInferenceProfiles",
        "bedrock:ListFoundationModels",
        "bedrock:GetInferenceProfile",
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "*"
    }
  ]
}
```

### jq not found

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Amazon Linux / RHEL
sudo yum install jq
```

## Architecture Notes

This project uses **two separate LiteLLM instances**:

1. **litellm** (port 4000) - Chat/text models
   - Config: `litellm-config.yaml`
   - Endpoint: `http://localhost:4000/v1`
   - Used by: `OPENAI_API_BASE_URL` in Open WebUI

2. **litellm-image** (port 4100) - Image generation models
   - Config: `litellm-image-config.yaml`
   - Endpoint: `http://localhost:4100/v1`
   - Used by: `IMAGES_OPENAI_API_BASE_URL` in Open WebUI

This separation ensures:
- Image requests use `/v1/images/generations` endpoint
- Chat requests use `/v1/chat/completions` endpoint
- No mixing of incompatible model types

## Related Documentation

- [AWS Bedrock Inference Profiles](https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles.html)
- [LiteLLM Bedrock Provider](https://docs.litellm.ai/docs/providers/bedrock)
- [Open WebUI Environment Variables](https://docs.openwebui.com/getting-started/env-configuration/)
