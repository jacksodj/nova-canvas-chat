# Image Generation Configuration Guide

This guide explains how Nova Canvas image generation is configured in this project and how to troubleshoot common issues.

## Key Configuration Issues Resolved

### Issue 1: Nova Canvas Doesn't Support Streaming

**Problem**: Nova Canvas is an image generation model that doesn't support streaming responses (unlike text models like Claude).

**Solution**: Set `stream: false` in the LiteLLM configuration.

```yaml
# litellm-config.yaml
model_list:
  - model_name: nova-canvas
    litellm_params:
      model: bedrock/amazon.nova-canvas-v1:0
      aws_region_name: us-east-1
      api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
      stream: false  # ← Critical: Image models don't support streaming
      api_base: bedrock-runtime
```

### Issue 2: Open WebUI Doesn't Know Which Model to Use

**Problem**: Open WebUI needs to be explicitly told which model to use for image generation requests.

**Solution**: Set `IMAGE_GENERATION_MODEL` environment variable.

#### Local Development (docker-compose.yml)

```yaml
openwebui:
  environment:
    - ENABLE_IMAGE_GENERATION=True
    - IMAGE_GENERATION_ENGINE=openai
    - IMAGE_GENERATION_MODEL=nova-canvas  # ← Tells WebUI to use nova-canvas
    - AUTOMATIC_IMAGE_GENERATION=False
```

#### Production (CloudFormation)

```yaml
Environment:
  - Name: ENABLE_IMAGE_GENERATION
    Value: "True"
  - Name: IMAGE_GENERATION_ENGINE
    Value: "openai"
  - Name: IMAGE_GENERATION_MODEL
    Value: "nova-canvas"  # ← Production configuration
  - Name: AUTOMATIC_IMAGE_GENERATION
    Value: "False"
```

## Complete Configuration Reference

### Model Configuration (litellm-config.yaml)

```yaml
model_list:
  # Image generation models - streaming must be disabled
  - model_name: nova-canvas
    litellm_params:
      model: bedrock/amazon.nova-canvas-v1:0
      aws_region_name: us-east-1
      api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
      stream: false  # ← Required for image models
      api_base: bedrock-runtime

  - model_name: titan-image
    litellm_params:
      model: bedrock/amazon.titan-image-generator-v2:0
      aws_region_name: us-east-1
      stream: false  # ← Required for image models

  # Text chat models - streaming can be enabled
  - model_name: claude-sonnet
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
      stream: true  # ← Text models support streaming

litellm_settings:
  drop_params: true  # Drop unsupported parameters
  set_verbose: true  # Enable verbose logging
```

### Open WebUI Configuration

| Environment Variable | Value | Purpose |
|---------------------|-------|---------|
| `ENABLE_IMAGE_GENERATION` | `True` | Enable image generation feature |
| `IMAGE_GENERATION_ENGINE` | `openai` | Use OpenAI-compatible API format |
| `IMAGE_GENERATION_MODEL` | `nova-canvas` | **Critical**: Specify which model to use |
| `AUTOMATIC_IMAGE_GENERATION` | `False` | Disable automatic image generation from text |
| `OPENAI_API_BASE_URL` | `http://litellm:4000/v1` | LiteLLM proxy endpoint |
| `OPENAI_API_KEY` | `sk-test-1234567890` | API key for LiteLLM |

## How Image Generation Works

```
┌─────────────────────────────────────────────────────────────┐
│                      USER REQUEST                            │
│  "Generate an image of a sunset over mountains"             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                   OPEN WEBUI                                 │
│  - Detects image generation intent                           │
│  - Uses IMAGE_GENERATION_MODEL=nova-canvas                   │
│  - Sends POST to /v1/images/generations                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│              LITELLM PROXY (Port 4000)                       │
│  - Routes to model: "nova-canvas"                            │
│  - Reads config: stream=false                                │
│  - Translates to Bedrock API format                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│         AWS BEDROCK - NOVA CANVAS MODEL                      │
│  - Generates image (5-7 seconds)                             │
│  - Returns base64-encoded PNG                                │
│  - No streaming support                                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                  IMAGE DISPLAYED                             │
│          In Open WebUI chat interface                        │
└──────────────────────────────────────────────────────────────┘
```

## Testing Image Generation

### Method 1: Through Open WebUI

1. **Start the services**:
   ```bash
   ./test-local.sh
   ```

2. **Open browser**: http://localhost:8080

3. **Test with explicit command**:
   ```
   /image a serene mountain landscape at sunset
   ```

4. **Or natural language** (if auto-detection is enabled):
   ```
   Generate an image of a serene mountain landscape at sunset
   ```

### Method 2: Direct API Call

```bash
# Set your API key
export AWS_BEARER_TOKEN_BEDROCK=your_api_key_here

# Test image generation via LiteLLM proxy
curl -X POST http://localhost:4000/v1/images/generations \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-test-1234567890' \
  -d '{
    "model": "nova-canvas",
    "prompt": "A serene mountain landscape at sunset",
    "n": 1,
    "size": "1024x1024"
  }'
```

### Method 3: Test All Models

```bash
# Test nova-canvas
curl -X POST http://localhost:4000/v1/images/generations \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-test-1234567890' \
  -d '{"model": "nova-canvas", "prompt": "sunset", "n": 1}'

# Test titan-image
curl -X POST http://localhost:4000/v1/images/generations \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-test-1234567890' \
  -d '{"model": "titan-image", "prompt": "sunset", "n": 1}'

# Test claude-sonnet (text chat)
curl -X POST http://localhost:4000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-test-1234567890' \
  -d '{"model": "claude-sonnet", "messages": [{"role": "user", "content": "Hello!"}]}'
```

## Troubleshooting

### Error: "Streaming not supported for image models"

**Cause**: The `stream` parameter is not set to `false` in litellm-config.yaml

**Solution**:
```yaml
# In litellm-config.yaml
- model_name: nova-canvas
  litellm_params:
    model: bedrock/amazon.nova-canvas-v1:0
    stream: false  # Add this line
```

### Error: "No image generation model configured"

**Cause**: `IMAGE_GENERATION_MODEL` environment variable is not set

**Solution for Local**:
```yaml
# In docker-compose.yml
environment:
  - IMAGE_GENERATION_MODEL=nova-canvas  # Add this line
```

**Solution for Production**:
```yaml
# In infrastructure/bedrock-image-chat-stack.yaml
- Name: IMAGE_GENERATION_MODEL
  Value: "nova-canvas"  # Add this
```

### Error: "Model not found: nova-canvas"

**Cause**: LiteLLM can't find the model in its configuration

**Solution**:
1. Check `litellm-config.yaml` has the model defined
2. Verify the config is mounted correctly in docker-compose.yml:
   ```yaml
   volumes:
     - ./litellm-config.yaml:/app/config.yaml:ro
   ```
3. Restart the containers:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Error: "Request timeout" or "Image generation takes too long"

**Cause**: Nova Canvas typically takes 5-7 seconds to generate images

**Solution**: This is normal behavior. Ensure:
1. No timeout is set too low
2. The UI shows a loading indicator
3. Streaming is disabled (streaming would make it worse)

### Images Not Appearing in Open WebUI

**Checklist**:
1. ✅ `ENABLE_IMAGE_GENERATION=True`
2. ✅ `IMAGE_GENERATION_ENGINE=openai`
3. ✅ `IMAGE_GENERATION_MODEL=nova-canvas`
4. ✅ `stream: false` in litellm-config.yaml
5. ✅ LiteLLM proxy is healthy: `curl http://localhost:4000/health`
6. ✅ Model access enabled in AWS Bedrock console

### Verify Configuration

```bash
# Check LiteLLM can see the models
curl http://localhost:4000/v1/models \
  -H 'Authorization: Bearer sk-test-1234567890'

# Should return:
# {
#   "data": [
#     {"id": "nova-canvas", ...},
#     {"id": "claude-sonnet", ...},
#     {"id": "titan-image", ...}
#   ]
# }

# Check Open WebUI environment
docker exec openwebui env | grep IMAGE_GENERATION

# Should show:
# ENABLE_IMAGE_GENERATION=True
# IMAGE_GENERATION_ENGINE=openai
# IMAGE_GENERATION_MODEL=nova-canvas
```

## Switching to Different Image Models

### Use Titan Image Generator Instead

```yaml
# In docker-compose.yml
environment:
  - IMAGE_GENERATION_MODEL=titan-image  # Change from nova-canvas
```

### Use Both Models (User Selectable)

Open WebUI allows users to select the model in the UI settings:

1. Configure multiple image models in `litellm-config.yaml`
2. In Open WebUI, go to Settings → Models
3. Select which model to use for image generation

## Performance Tuning

### Nova Canvas Performance

- **Generation Time**: 5-7 seconds per image
- **Resolution**: 1024x1024 (default)
- **Cost**: ~$0.04 per image (on-demand)
- **Throughput**: Up to 10,000 images/day (on-demand)

### For Higher Throughput

Use provisioned throughput:

```yaml
# In litellm-config.yaml
- model_name: nova-canvas-provisioned
  litellm_params:
    model: bedrock/arn:aws:bedrock:us-east-1:123456789:provisioned-model/your-id
    aws_region_name: us-east-1
    stream: false
```

Benefits:
- Guaranteed capacity
- Lower per-image cost (with commitment)
- Faster response times

## Security Best Practices

### 1. Don't Enable Automatic Image Generation

```yaml
# Recommended
AUTOMATIC_IMAGE_GENERATION=False
```

Why: Prevents unexpected API costs from users triggering image generation unintentionally.

### 2. Use IAM Roles in Production

```yaml
# Production - don't use API keys
# Use IAM roles assigned to ECS tasks instead
# (already configured in CloudFormation)
```

### 3. Rate Limiting

Consider adding rate limiting at the ALB level:
- Max requests per IP: 100/minute
- Prevents abuse and controls costs

## References

- [AWS Bedrock Nova Canvas Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-nova-canvas.html)
- [LiteLLM Configuration Guide](https://docs.litellm.ai/docs/proxy/configs)
- [Open WebUI Environment Variables](https://docs.openwebui.com/getting-started/env-configuration)
- [Bedrock Image Generation API](https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_InvokeModel.html)

## Quick Reference

```bash
# Configuration locations
litellm-config.yaml              # Model definitions, streaming config
docker-compose.yml               # Local env vars
infrastructure/...stack.yaml     # Production env vars

# Critical settings
stream: false                    # In litellm-config.yaml for image models
IMAGE_GENERATION_MODEL           # Must be set in Open WebUI env

# Test commands
curl localhost:4000/v1/models                    # List models
curl localhost:4000/v1/images/generations        # Generate image
curl localhost:8080/health                       # Check Open WebUI

# Logs
docker compose logs -f litellm      # LiteLLM proxy logs
docker compose logs -f openwebui    # Open WebUI logs
```
