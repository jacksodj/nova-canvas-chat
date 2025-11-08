# Open WebUI + LiteLLM + AWS Bedrock Configuration Guide

## Critical Architecture Principle

**Open WebUI REQUIRES separate API endpoints for chat and image generation.**

### Why This Matters

Open WebUI makes different API calls depending on the operation:
- **Chat/text requests** → `/v1/chat/completions`
- **Image generation requests** → `/v1/images/generations`

If you put both chat models (like Claude) and image models (like Nova Canvas) in the SAME LiteLLM instance:
- ❌ Image generation via `/image` command or UI button will fail
- ❌ Error: `"required key [messages] not found"` (trying to use image model as chat model)
- ❌ Or: Nova Canvas appears in chat model selector (wrong!)

### Correct Architecture

```
┌─────────────────┐
│   Open WebUI    │
│   (port 8080)   │
└────────┬────────┘
         │
         ├──── Chat requests ────────────┐
         │     (OPENAI_API_BASE_URL)     │
         │                               ▼
         │                    ┌──────────────────────┐
         │                    │  LiteLLM (port 4000) │
         │                    │  Chat models only:   │
         │                    │  - Claude Sonnet 4   │
         │                    │  - Other text models │
         │                    └──────────────────────┘
         │
         └──── Image requests ───────────┐
               (IMAGES_OPENAI_API_BASE_URL)
                                         ▼
                              ┌──────────────────────────┐
                              │  LiteLLM-Image (4100)    │
                              │  Image models only:      │
                              │  - Nova Canvas           │
                              │  - Stable Diffusion      │
                              └──────────────────────────┘
```

## Problem 1: Streaming Errors with Image Models

### Symptom
```
litellm.BadRequestError: BedrockException -
{"message":"The model is unsupported for streaming."}
```

### Root Cause
- Open WebUI sends `stream=true` by default for some requests
- Image generation models (Nova Canvas, Stable Diffusion) don't support streaming
- LiteLLM was honoring the client's streaming request

### Why `drop_params` Alone Doesn't Work
The `drop_params: true` setting only drops parameters **before sending to Bedrock**, but LiteLLM still tries to create a streaming response wrapper if the client requested it.

### Solution
**Use separate LiteLLM instances** - this naturally prevents the issue because:
1. Image models are in their own instance
2. Open WebUI calls the correct endpoint (`/v1/images/generations`)
3. That endpoint doesn't use streaming

### What Didn't Work
- ❌ Setting `stream: false` in litellm_params (client override wins)
- ❌ Using `additional_drop_params: ["stream"]` (incomplete fix)
- ❌ Mixing chat and image models in one instance

## Problem 2: Claude Model Inference Profile Requirement

### Symptom
```
litellm.BadRequestError: BedrockException -
{"message":"Invocation of model ID anthropic.claude-3-5-sonnet-20241022-v2:0
with on-demand throughput isn't supported. Retry your request with the ID or
ARN of an inference profile that contains this model."}
```

### Root Cause
Newer Claude models on Bedrock (3.5 Sonnet v2, Sonnet 4, etc.) require **system inference profiles** instead of direct model IDs.

### Solution
Use the `us.` prefixed inference profile ID:

❌ **Wrong:**
```yaml
model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
```

✅ **Correct:**
```yaml
model: bedrock/us.anthropic.claude-3-5-sonnet-20241022-v2:0
# or for Sonnet 4:
model: bedrock/us.anthropic.claude-sonnet-4-20250514-v1:0
```

### Why Inference Profiles?
The `us.` prefix enables AWS to:
- Automatically route requests across regions (us-east-1, us-west-2, etc.)
- Provide better load balancing
- Improve availability and throughput

### How to Find Available Inference Profiles
```bash
aws bedrock list-inference-profiles --region us-east-1
```

Look for `status: "ACTIVE"` and `inferenceProfileId` starting with `us.`

## Problem 3: Open WebUI Environment Variable Confusion

### The Key Variables

#### For Chat/Text Models
```yaml
OPENAI_API_BASE_URL=http://litellm:4000/v1
OPENAI_API_KEY=sk-test-1234567890
```

These control **ALL chat/text interactions**:
- Model list in UI
- Chat completions
- Streaming responses

#### For Image Generation
```yaml
IMAGE_GENERATION_ENGINE=openai
IMAGE_GENERATION_MODEL=nova-canvas
IMAGES_OPENAI_API_BASE_URL=http://litellm-image:4100/v1
IMAGES_OPENAI_API_KEY=sk-test-1234567890
```

These control **ONLY image generation**:
- `/image` command
- Image generation button in UI
- Image editing features

### Critical: Must Set IMAGES_OPENAI_API_BASE_URL

❌ **Missing this causes the core problem:**
```yaml
# IMAGES_OPENAI_API_BASE_URL not set
```
Result: Open WebUI uses `OPENAI_API_BASE_URL` for images too, sending image requests to the chat endpoint, causing "messages not found" errors.

✅ **Correct:**
```yaml
IMAGES_OPENAI_API_BASE_URL=http://litellm-image:4100/v1
```

## Problem 4: Understanding How `/image` Command Works

### What Happens When User Types `/image sunset over mountains`

1. **Open WebUI detects the image intent**
   - Could be `/image` command
   - Could be clicking image generation button
   - Could be automatic detection (if enabled)

2. **Open WebUI calls the IMAGE endpoint**
   ```
   POST {IMAGES_OPENAI_API_BASE_URL}/images/generations
   {
     "model": "nova-canvas",  // from IMAGE_GENERATION_MODEL
     "prompt": "sunset over mountains",
     "n": 1
   }
   ```

3. **LiteLLM-Image receives the request**
   - Looks up "nova-canvas" in its config
   - Translates to Bedrock format
   - Calls `bedrock/amazon.nova-canvas-v1:0`

4. **Bedrock generates the image**
   - Returns base64 or URL
   - LiteLLM formats as OpenAI-compatible response
   - Open WebUI displays in chat

### What Goes Wrong with Single LiteLLM Instance

If you have both models in one instance:

1. User types `/image sunset`
2. Open WebUI calls `POST /v1/images/generations` with `model: "nova-canvas"`
3. **But user has nova-canvas selected as their CHAT model too**
4. Or Open WebUI gets confused about which model to use
5. Or it calls `/v1/chat/completions` instead (wrong endpoint)
6. Error: "messages not found" or streaming error

## Docker Compose Configuration

### Complete Working Setup

```yaml
services:
  litellm-db:
    image: postgres:16-alpine
    container_name: litellm-db
    environment:
      POSTGRES_USER: litellm_user
      POSTGRES_PASSWORD: ${POSTGRE_PASSWORD}
      POSTGRES_DB: litellm_db
    volumes:
      - litellm_db_data:/var/lib/postgresql/data

  # CHAT MODELS INSTANCE
  litellm:
    image: ghcr.io/berriai/litellm:main-stable
    container_name: litellm-proxy
    ports:
      - "4000:4000"
    environment:
      - AWS_REGION_NAME=us-east-1
      - LITELLM_MODE=PROXY
      - LITELLM_MASTER_KEY=sk-test-1234567890
      - DATABASE_URL=postgresql://litellm_user:${POSTGRE_PASSWORD}@litellm-db:5432/litellm_db
      - AWS_BEARER_TOKEN_BEDROCK=${AWS_BEARER_TOKEN_BEDROCK}
    volumes:
      - ~/.aws:/root/.aws:ro
      - ./litellm-config.yaml:/app/config.yaml:ro
    command: ["--config", "/app/config.yaml", "--port", "4000", "--host", "0.0.0.0"]

  # IMAGE MODELS INSTANCE
  litellm-image:
    image: ghcr.io/berriai/litellm:main-stable
    container_name: litellm-image-proxy
    ports:
      - "4100:4100"
    environment:
      - AWS_REGION_NAME=us-east-1
      - LITELLM_MODE=PROXY
      - LITELLM_MASTER_KEY=sk-test-1234567890
      - DATABASE_URL=postgresql://litellm_user:${POSTGRE_PASSWORD}@litellm-db:5432/litellm_db
      - AWS_BEARER_TOKEN_BEDROCK=${AWS_BEARER_TOKEN_BEDROCK}
    volumes:
      - ~/.aws:/root/.aws:ro
      - ./litellm-image-config.yaml:/app/config.yaml:ro
    command: ["--config", "/app/config.yaml", "--port", "4100", "--host", "0.0.0.0"]

  openwebui:
    image: ghcr.io/open-webui/open-webui:v0.6.36
    container_name: openwebui
    ports:
      - "8080:8080"
    environment:
      # CHAT ENDPOINT
      - OPENAI_API_BASE_URL=http://litellm:4000/v1
      - OPENAI_API_KEY=sk-test-1234567890

      # IMAGE ENDPOINT (CRITICAL!)
      - ENABLE_IMAGE_GENERATION=True
      - IMAGE_GENERATION_ENGINE=openai
      - IMAGE_GENERATION_MODEL=nova-canvas
      - IMAGES_OPENAI_API_BASE_URL=http://litellm-image:4100/v1
      - IMAGES_OPENAI_API_KEY=sk-test-1234567890

      - WEBUI_AUTH=False
      - AUTOMATIC_IMAGE_GENERATION=False
    volumes:
      - open-webui-data:/app/backend/data
    depends_on:
      - litellm
      - litellm-image

volumes:
  open-webui-data:
  litellm_db_data:
```

## LiteLLM Config Files

### litellm-config.yaml (Chat Models Only)

```yaml
model_list:
  - model_name: claude-sonnet
    litellm_params:
      model: bedrock/us.anthropic.claude-sonnet-4-20250514-v1:0
      aws_region_name: us-east-1
      stream: true  # Chat models support streaming

litellm_settings:
  drop_params: true
  set_verbose: true
```

### litellm-image-config.yaml (Image Models Only)

```yaml
model_list:
  - model_name: nova-canvas
    litellm_params:
      model: bedrock/amazon.nova-canvas-v1:0
      aws_region_name: us-east-1
      # NO stream parameter needed - images don't stream

  - model_name: stable-diffusion-3-5
    litellm_params:
      model: bedrock/stability.sd3-5-large-v1:0
      aws_region_name: us-west-2

litellm_settings:
  drop_params: true
  set_verbose: true
```

## Automated Model Discovery

### Generate All Available Models

```bash
# Chat/text models with inference profiles
aws bedrock list-inference-profiles --region us-east-1 | \
  jq -r '.inferenceProfileSummaries[] |
    select(.status=="ACTIVE") |
    "- model_name: \"\(.inferenceProfileName)\"\n  litellm_params:\n    model: bedrock/\(.inferenceProfileId)\n    aws_region_name: us-east-1\n"'

# Foundation models with streaming support
aws bedrock list-foundation-models --region us-east-1 | \
  jq -r '.modelSummaries[] |
    select(
      .modelLifecycle.status == "ACTIVE" and
      (.responseStreamingSupported == true) and
      (.inferenceTypesSupported | contains(["ON_DEMAND"])) and
      (.inputModalities | contains(["TEXT"])) and
      (.outputModalities | contains(["TEXT"]))
    ) |
    "- model_name: \"\(.modelName)\"\n  litellm_params:\n    model: bedrock/\(.modelId)\n    aws_region_name: us-east-1\n    stream: true\n"'
```

### Generate Image Models

```bash
aws bedrock list-foundation-models --region us-east-1 | \
  jq -r '.modelSummaries[] |
    select(
      .modelLifecycle.status == "ACTIVE" and
      (.inferenceTypesSupported | contains(["ON_DEMAND"])) and
      (.inputModalities | contains(["TEXT"])) and
      (.outputModalities | contains(["IMAGE"]))
    ) |
    "- model_name: \"\(.modelName)\"\n  litellm_params:\n    model: bedrock/\(.modelId)\n    aws_region_name: us-east-1\n"'
```

## Testing and Verification

### 1. Verify LiteLLM Endpoints

```bash
# Chat endpoint - should show chat models only
curl http://localhost:4000/v1/models \
  -H 'Authorization: Bearer sk-test-1234567890'

# Image endpoint - should show image models only
curl http://localhost:4100/v1/models \
  -H 'Authorization: Bearer sk-test-1234567890'
```

### 2. Test Image Generation via API

```bash
# This should work
curl -X POST http://localhost:4100/v1/images/generations \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-test-1234567890' \
  -d '{
    "model": "nova-canvas",
    "prompt": "sunset over mountains",
    "n": 1
  }'
```

### 3. Test in Open WebUI

1. Open http://localhost:8080
2. **Select claude-sonnet from the model dropdown** (important!)
3. Type: `/image sunset over mountains`
4. Should generate image without errors

## Common Errors and Solutions

### Error: "required key [messages] not found"

**Cause:** Image model being called via chat completions endpoint

**Check:**
- Is `IMAGES_OPENAI_API_BASE_URL` set correctly?
- Are chat and image models in separate LiteLLM instances?
- Did you restart Open WebUI after config changes?

**Solution:**
```bash
docker compose down
docker compose up -d
```

### Error: "The model is unsupported for streaming"

**Cause:** Streaming enabled for image generation model

**Check:**
- Is the model in the correct config file (litellm-image-config.yaml)?
- Is Open WebUI calling the right endpoint?

**Solution:**
Ensure separate instances with proper `IMAGES_OPENAI_API_BASE_URL`

### Error: "Invocation of model ID with on-demand throughput isn't supported"

**Cause:** Using direct model ID instead of inference profile for Claude

**Solution:**
Change from:
```yaml
model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
```
To:
```yaml
model: bedrock/us.anthropic.claude-3-5-sonnet-20241022-v2:0
```

### Nova Canvas doesn't appear in Open WebUI

**This is CORRECT behavior!**

Nova Canvas should NOT appear in the chat model selector. It's only used for image generation via:
- `/image` command
- Image generation button
- Set via `IMAGE_GENERATION_MODEL` environment variable

If you see image models in the chat selector, you've mixed them incorrectly.

## Key Takeaways

1. **Always use separate LiteLLM instances** for chat and image models
2. **Always set IMAGES_OPENAI_API_BASE_URL** - it's not optional
3. **Use inference profiles** (`us.` prefix) for newer Claude models
4. **Image models don't stream** - don't try to force it
5. **The `/image` command calls a different endpoint** than chat
6. **Auto-discover models** instead of manually maintaining configs
7. **Open WebUI v0.6.35+** has important image generation fixes

## Reference Architecture

This configuration is based on production CloudFormation templates and represents the correct, battle-tested approach for running Open WebUI with Bedrock models.

**Do not:**
- ❌ Mix chat and image models in one LiteLLM instance
- ❌ Try to create custom Open WebUI tools/functions for image generation
- ❌ Use direct model IDs for newer Claude models
- ❌ Omit IMAGES_OPENAI_API_BASE_URL

**Do:**
- ✅ Separate instances (port 4000 for chat, 4100 for images)
- ✅ Use inference profiles for Claude
- ✅ Set both OPENAI_API_BASE_URL and IMAGES_OPENAI_API_BASE_URL
- ✅ Keep configs simple and let the architecture handle the complexity

## Version Information

- **Open WebUI:** v0.6.36+ (v0.6.35+ has critical image generation fixes)
- **LiteLLM:** main-stable (supports Bedrock Nova Canvas as of v1.63.11+)
- **Bedrock Models:**
  - Claude Sonnet 4: `us.anthropic.claude-sonnet-4-20250514-v1:0`
  - Nova Canvas: `amazon.nova-canvas-v1:0`
