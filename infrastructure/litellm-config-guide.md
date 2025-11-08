# LiteLLM Configuration Guide for Bedrock Models

This guide explains how to configure LiteLLM to work with AWS Bedrock models, including fine-tuned models with provisioned throughput.

## Overview

LiteLLM acts as a proxy between Open WebUI and AWS Bedrock, providing OpenAI-compatible API endpoints for both text and image generation models.

**Pre-configured Models (Ready to Use):**
The CloudFormation stack automatically configures these on-demand models:
- ✅ `nova-canvas` - Amazon Nova Canvas v1.0 (image generation)
- ✅ `claude-sonnet` - Claude 3.5 Sonnet v2 (text chat with streaming)

**No manual configuration needed!** These models work immediately after deployment.

## Adding Additional Models

This section is optional - only needed if you want to add more models beyond the default configuration.

### Model Configuration via UI

After deploying the stack, you can configure additional models through the LiteLLM UI:

1. Access LiteLLM admin UI (if exposed) or use the API directly
2. Add models using the LiteLLM proxy admin API

## Configuring Models via API

### 1. Get the LiteLLM API Key

```bash
# Retrieve the API key from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id bedrock-image-chat/litellm-api-key \
  --query SecretString \
  --output text | jq -r '.api_key'
```

### 2. Add Standard Bedrock Models

#### Amazon Nova Canvas (Image Generation)

```bash
curl -X POST 'http://litellm:4000/model/new' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_API_KEY' \
  -d '{
    "model_name": "nova-canvas",
    "litellm_params": {
      "model": "bedrock/amazon.nova-canvas-v1:0",
      "aws_region_name": "us-east-1"
    }
  }'
```

#### Amazon Nova Canvas (Image Generation)

```bash
curl -X POST 'http://litellm:4000/model/new' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_API_KEY' \
  -d '{
    "model_name": "nova-canvas",
    "litellm_params": {
      "model": "bedrock/amazon.nova-canvas-v1:0",
      "aws_region_name": "us-east-1",
    }
  }'
```

#### Claude 3.5 Sonnet (Text Generation)

```bash
curl -X POST 'http://litellm:4000/model/new' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_API_KEY' \
  -d '{
    "model_name": "claude-sonnet",
    "litellm_params": {
      "model": "bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0",
      "aws_region_name": "us-east-1",
      "stream": true
    }
  }'
```

## Provisioned Throughput Models

### Understanding Provisioned Throughput

Provisioned throughput provides:
- **Guaranteed capacity**: Reserved model inference capacity
- **Consistent performance**: No throttling during high demand
- **Lower latency**: Faster response times
- **Predictable costs**: Fixed hourly pricing

### Prerequisites

1. **Purchase Provisioned Throughput**:
   ```bash
   # Create provisioned throughput for Nova Canvas
   aws bedrock create-provisioned-model-throughput \
     --provisioned-model-name "my-nova-canvas-provisioned" \
     --model-id "amazon.nova-canvas-v1:0" \
     --model-units 1 \
     --commitment-duration "OneMonth" \
     --region us-east-1
   ```

2. **Wait for Provisioning** (takes 10-15 minutes):
   ```bash
   # Check status
   aws bedrock get-provisioned-model-throughput \
     --provisioned-model-id "YOUR_PROVISIONED_MODEL_ID" \
     --region us-east-1
   ```

3. **Get the Provisioned Model ARN**:
   ```bash
   aws bedrock list-provisioned-model-throughputs \
     --region us-east-1 \
     --query 'provisionedModelSummaries[?provisionedModelName==`my-nova-canvas-provisioned`].provisionedModelArn' \
     --output text
   ```

### Configuring Provisioned Models in LiteLLM

#### Method 1: Using Provisioned Model ARN Directly

```bash
curl -X POST 'http://litellm:4000/model/new' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_API_KEY' \
  -d '{
    "model_name": "nova-canvas-provisioned",
    "litellm_params": {
      "model": "bedrock/arn:aws:bedrock:us-east-1:123456789012:provisioned-model/xxxxxxxxxxxxx",
      "aws_region_name": "us-east-1"
    }
  }'
```

#### Method 2: Using Provisioned Model ID

```bash
curl -X POST 'http://litellm:4000/model/new' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_API_KEY' \
  -d '{
    "model_name": "nova-canvas-provisioned",
    "litellm_params": {
      "model": "bedrock/provisioned/my-nova-canvas-provisioned",
      "aws_region_name": "us-east-1"
    }
  }'
```

### Fine-Tuned Models with Provisioned Throughput

If you have a fine-tuned Nova model:

1. **Create Custom Model Job** (done beforehand):
   ```bash
   aws bedrock create-model-customization-job \
     --job-name "my-custom-nova-model" \
     --custom-model-name "custom-nova-canvas" \
     --base-model-identifier "amazon.nova-canvas-v1:0" \
     --training-data-config "s3Uri=s3://my-bucket/training-data" \
     --output-data-config "s3Uri=s3://my-bucket/output" \
     --role-arn "arn:aws:iam::123456789012:role/BedrockCustomizationRole"
   ```

2. **Purchase Provisioned Throughput for Custom Model**:
   ```bash
   aws bedrock create-provisioned-model-throughput \
     --provisioned-model-name "custom-nova-provisioned" \
     --model-id "arn:aws:bedrock:us-east-1:123456789012:custom-model/custom-nova-canvas/xxxxx" \
     --model-units 2 \
     --commitment-duration "SixMonths"
   ```

3. **Configure in LiteLLM**:
   ```bash
   curl -X POST 'http://litellm:4000/model/new' \
     -H 'Content-Type: application/json' \
     -H 'Authorization: Bearer YOUR_API_KEY' \
     -d '{
       "model_name": "custom-nova-provisioned",
       "litellm_params": {
         "model": "bedrock/arn:aws:bedrock:us-east-1:123456789012:provisioned-model/yyyyyyyyyyyyy",
         "aws_region_name": "us-east-1",
         "max_tokens": 1024
       }
     }'
   ```

## Configuration File Approach (Alternative)

If you prefer to use a configuration file, you can create a `litellm_config.yaml`:

```yaml
model_list:
  # Standard on-demand models
  - model_name: nova-canvas
    litellm_params:
      model: bedrock/amazon.nova-canvas-v1:0
      aws_region_name: us-east-1

  - model_name: claude-sonnet
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
      stream: true

  # Provisioned throughput models
  - model_name: nova-canvas-provisioned
    litellm_params:
      model: bedrock/arn:aws:bedrock:us-east-1:123456789012:provisioned-model/xxxxxxxxxxxxx
      aws_region_name: us-east-1

  - model_name: custom-nova-provisioned
    litellm_params:
      model: bedrock/arn:aws:bedrock:us-east-1:123456789012:provisioned-model/yyyyyyyyyyyyy
      aws_region_name: us-east-1

litellm_settings:
  drop_params: true
  set_verbose: true
```

### Mounting Config File (Requires Stack Update)

To use this approach, you would need to:

1. Store the config in S3 or Systems Manager Parameter Store
2. Update the ECS task definition to fetch and mount the config
3. Modify the container command to use `--config /path/to/config.yaml`

## Model Aliases and Load Balancing

You can create aliases that load balance between on-demand and provisioned models:

```yaml
model_list:
  - model_name: nova-canvas-primary
    litellm_params:
      model: bedrock/arn:aws:bedrock:us-east-1:123456789012:provisioned-model/xxxxx
      aws_region_name: us-east-1

  - model_name: nova-canvas-fallback
    litellm_params:
      model: bedrock/amazon.nova-canvas-v1:0
      aws_region_name: us-east-1

router_settings:
  routing_strategy: simple-shuffle
  model_group_alias:
    nova-canvas:
      - nova-canvas-primary
      - nova-canvas-fallback
```

## Verifying Model Configuration

### List All Models

```bash
curl -X GET 'http://litellm:4000/model/info' \
  -H 'Authorization: Bearer YOUR_API_KEY'
```

### Test Image Generation

```bash
curl -X POST 'http://litellm:4000/v1/images/generations' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_API_KEY' \
  -d '{
    "model": "nova-canvas-provisioned",
    "prompt": "A serene mountain landscape at sunset",
    "n": 1,
    "size": "1024x1024"
  }'
```

### Test Text Generation

```bash
curl -X POST 'http://litellm:4000/v1/chat/completions' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_API_KEY' \
  -d '{
    "model": "claude-sonnet",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": false
  }'
```

## Cost Considerations

### Provisioned Throughput Pricing (Example for us-east-1)

| Model | Model Units | Hourly Cost | Monthly Cost (730 hrs) |
|-------|-------------|-------------|------------------------|
| Nova Canvas | 1 unit | ~$6.00 | ~$4,380 |
| Claude 3.5 Sonnet | 1 unit | ~$8.00 | ~$5,840 |

**Commitment Discounts:**
- 1 month: Base price
- 6 months: ~30% discount
- 1 year: ~50% discount

### When to Use Provisioned Throughput

✅ **Use provisioned throughput when:**
- You have predictable, consistent traffic
- You need guaranteed low latency
- You're generating >10,000 images/day
- You want to avoid throttling

❌ **Stick with on-demand when:**
- Traffic is sporadic or unpredictable
- You're in development/testing phase
- Cost optimization is critical
- Usage is <5,000 images/day

## Monitoring Provisioned Models

```bash
# Check provisioned model utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/Bedrock \
  --metric-name ModelInvocations \
  --dimensions Name=ProvisionedModelId,Value=YOUR_MODEL_ID \
  --start-time 2025-11-01T00:00:00Z \
  --end-time 2025-11-01T23:59:59Z \
  --period 3600 \
  --statistics Sum \
  --region us-east-1
```

## Troubleshooting

### Issue: "Model not found" error

**Solution**: Verify model access in Bedrock console:
```bash
aws bedrock list-foundation-models --region us-east-1
aws bedrock list-provisioned-model-throughputs --region us-east-1
```

### Issue: Provisioned model throttling

**Solution**: Check if you've exceeded provisioned capacity:
- Each model unit provides specific throughput
- May need to purchase additional units

### Issue: Authentication errors

**Solution**: Verify IAM role has correct permissions:
```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
    "bedrock:GetProvisionedModelThroughput"
  ],
  "Resource": [
    "arn:aws:bedrock:us-east-1::foundation-model/*",
    "arn:aws:bedrock:us-east-1:123456789012:provisioned-model/*"
  ]
}
```

## Additional Resources

- [LiteLLM Bedrock Documentation](https://docs.litellm.ai/docs/providers/bedrock)
- [AWS Bedrock Provisioned Throughput](https://docs.aws.amazon.com/bedrock/latest/userguide/prov-throughput.html)
- [Bedrock Model IDs](https://docs.aws.amazon.com/bedrock/latest/userguide/model-ids.html)
- [Nova Canvas Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-nova-canvas.html)
