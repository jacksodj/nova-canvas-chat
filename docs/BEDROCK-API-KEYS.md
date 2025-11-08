# AWS Bedrock API Keys - Authentication Guide

This guide explains how to use AWS Bedrock API Keys (bearer tokens) for authenticating to Amazon Bedrock services.

## Overview

AWS Bedrock now supports API keys as a simpler alternative to traditional IAM credentials. These API keys work as bearer tokens and can be passed directly in HTTP requests.

## Why Use API Keys?

### ✅ Advantages
- **Simpler setup**: No need to configure AWS CLI or manage access keys
- **Quick start**: Generate a key in seconds and start using immediately
- **Scoped permissions**: Keys are limited to Bedrock API calls only
- **Not logged**: API keys aren't logged in CloudTrail for privacy

### ⚠️ Considerations
- **Long-term keys**: Permanent until manually deleted (rotate regularly)
- **Short-term keys**: Session-based, expire after 12 hours max
- **Security**: Treat like passwords - never commit to source control

## How to Generate an API Key

### Using AWS Console

1. **Navigate to Bedrock Console**
   - Go to: https://console.aws.amazon.com/bedrock/api-keys
   - Or: AWS Console → Services → Amazon Bedrock → API keys

2. **Create API Key**

   **For Development (Long-term key)**:
   - Click "Create API key"
   - Select "Long-term"
   - Give it a descriptive name (e.g., "dev-local-testing")
   - Click "Create"
   - **Important**: Copy the key immediately - it won't be shown again!

   **For Testing (Short-term key)**:
   - Click "Create API key"
   - Select "Short-term"
   - Key expires with your session (max 12 hours)
   - Better for quick experiments

3. **Save Your Key Securely**
   ```bash
   # Save to environment variable
   export AWS_BEARER_TOKEN_BEDROCK=your_api_key_here

   # Or add to .env file (DO NOT commit to git!)
   echo "AWS_BEARER_TOKEN_BEDROCK=your_api_key_here" >> .env
   ```

### Using AWS CLI

```bash
# Generate long-term API key
aws bedrock create-api-key \
  --name "my-dev-key" \
  --region us-east-1

# The response contains your API key - save it securely!
```

## How to Use with This Project

### Local Development

1. **Set the environment variable**:
   ```bash
   export AWS_BEARER_TOKEN_BEDROCK=your_api_key_here
   ```

2. **Start the services**:
   ```bash
   ./test-local.sh
   ```

3. **The configuration is already set up** in:
   - `litellm-config.yaml` (line 6) - References the environment variable
   - `docker-compose.yml` (line 27) - Passes it to the LiteLLM container

### Production (AWS ECS)

For production deployments, it's recommended to use IAM roles instead of API keys:

```yaml
# Already configured in infrastructure/bedrock-image-chat-stack.yaml
ECSTaskRole:
  Type: AWS::IAM::Role
  Properties:
    Policies:
      - PolicyName: BedrockAccess
        PolicyDocument:
          Statement:
            - Effect: Allow
              Action:
                - bedrock:InvokeModel
                - bedrock:InvokeModelWithResponseStream
              Resource: "*"
```

## Authentication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR APPLICATION                          │
│  Sets: AWS_BEARER_TOKEN_BEDROCK=sk-xxxxx                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                  LITELLM PROXY                               │
│  Reads: os.environ/AWS_BEARER_TOKEN_BEDROCK                 │
│  Adds: Authorization: Bearer sk-xxxxx                        │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTPS Request
                       ▼
┌──────────────────────────────────────────────────────────────┐
│              AWS BEDROCK RUNTIME API                         │
│  Validates: Bearer token                                     │
│  Executes: Nova Canvas image generation                      │
└──────────────────────┬──────────────────────────────────────┘
                       │ Image returned
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                     RESPONSE                                 │
│  Base64-encoded PNG image                                    │
└──────────────────────────────────────────────────────────────┘
```

## Testing Your API Key

### Test with cURL

```bash
# Set your API key
export AWS_BEARER_TOKEN_BEDROCK=your_api_key_here

# Test image generation
curl -X POST https://bedrock-runtime.us-east-1.amazonaws.com/model/amazon.nova-canvas-v1:0/invoke \
  -H "Authorization: Bearer $AWS_BEARER_TOKEN_BEDROCK" \
  -H "Content-Type: application/json" \
  -d '{
    "textToImageParams": {
      "text": "A serene mountain landscape"
    },
    "taskType": "TEXT_IMAGE",
    "imageGenerationConfig": {
      "numberOfImages": 1,
      "quality": "standard",
      "height": 1024,
      "width": 1024
    }
  }'
```

### Test with LiteLLM

```bash
# Start your local environment
./test-local.sh

# Test through LiteLLM proxy
curl -X POST http://localhost:4000/v1/images/generations \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-test-1234567890' \
  -d '{
    "model": "nova-canvas",
    "prompt": "A sunset over mountains",
    "n": 1
  }'
```

## Security Best Practices

### ✅ DO

1. **Use short-term keys for testing**
   - Automatically expire after your session
   - Less risk if accidentally exposed

2. **Rotate long-term keys regularly**
   - Create new key every 90 days
   - Delete old keys after rotation

3. **Use environment variables**
   ```bash
   # Good
   export AWS_BEARER_TOKEN_BEDROCK=sk-xxxxx

   # Better - load from .env
   echo "AWS_BEARER_TOKEN_BEDROCK=sk-xxxxx" >> .env
   source .env
   ```

4. **Use IAM roles in production**
   - ECS tasks get credentials automatically
   - No need to manage keys manually

### ❌ DON'T

1. **Never commit API keys to git**
   ```bash
   # Add to .gitignore (already included)
   .env
   *.key
   *.secret
   ```

2. **Don't share keys publicly**
   - Treat like passwords
   - Revoke immediately if exposed

3. **Don't hardcode in source code**
   ```python
   # Bad
   api_key = "sk-xxxxx"

   # Good
   api_key = os.environ["AWS_BEARER_TOKEN_BEDROCK"]
   ```

## Troubleshooting

### Error: "Invalid bearer token"

**Cause**: Token is expired, invalid, or not set correctly

**Solution**:
```bash
# Check if variable is set
echo $AWS_BEARER_TOKEN_BEDROCK

# If empty, set it:
export AWS_BEARER_TOKEN_BEDROCK=your_api_key_here

# Verify it's passed to Docker
docker compose config | grep AWS_BEARER_TOKEN_BEDROCK
```

### Error: "Access denied"

**Cause**: API key doesn't have Bedrock permissions

**Solution**:
1. Go to AWS Console → Bedrock → API keys
2. Verify the key exists and is active
3. Check that you have Bedrock model access enabled
4. Generate a new key if needed

### Error: "Missing credentials"

**Cause**: Environment variable not set

**Solution**:
```bash
# Option 1: Export manually
export AWS_BEARER_TOKEN_BEDROCK=your_api_key_here

# Option 2: Load from .env
source .env

# Option 3: Use IAM credentials instead
aws configure
# Then remove api_key line from litellm-config.yaml
```

## Alternative: IAM Credentials

If you prefer traditional AWS authentication:

1. **Configure AWS CLI**:
   ```bash
   aws configure
   ```

2. **Remove API key from config**:
   ```yaml
   # In litellm-config.yaml, remove the api_key line:
   - model_name: nova-canvas
     litellm_params:
       model: bedrock/amazon.nova-canvas-v1:0
       aws_region_name: us-east-1
       # api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK  # Remove this
       stream: false
   ```

3. **Credentials are loaded from ~/.aws/credentials** (already mounted in docker-compose.yml)

## References

- [AWS Bedrock API Keys Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/api-keys.html)
- [Bedrock API Keys Blog Post](https://aws.amazon.com/blogs/machine-learning/accelerate-ai-development-with-amazon-bedrock-api-keys/)
- [LiteLLM Bedrock Provider Docs](https://docs.litellm.ai/docs/providers/bedrock)
- [Security Best Practices](https://prowler.com/blog/bedrocks-new-api-keys-convenience-at-a-hidden-security-cost)

## Quick Reference

```bash
# Generate API key (Console)
https://console.aws.amazon.com/bedrock/api-keys

# Set environment variable
export AWS_BEARER_TOKEN_BEDROCK=your_key_here

# Test locally
./test-local.sh

# Access UI
http://localhost:8080

# Revoke key (Console)
AWS Console → Bedrock → API keys → Select key → Delete
```
