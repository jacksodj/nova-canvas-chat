# Quick Start: Adding Fine-Tuned Nova Canvas Models

This guide shows you how to discover and add fine-tuned Nova Canvas models to your deployment in **under 5 minutes**.

## 🚀 Quick Start (TL;DR)

```bash
# 1. Discover all your models
cd infrastructure
./discover-models.sh us-east-1

# 2. It automatically generates litellm-config-generated.yaml with ALL your models
# 3. Copy it to your config
cp litellm-config-generated.yaml litellm-config.yaml

# 4. Deploy or update your stack
# (see output from discover-models.sh for exact commands)
```

## 📋 Step-by-Step Guide

### Step 1: Discover Your Models

The easiest way to find all your models (fine-tuned, provisioned, on-demand):

```bash
cd infrastructure
./discover-models.sh us-east-1
```

**This script will:**
- ✅ List all foundation models (Nova Canvas, etc.)
- ✅ List all fine-tuned/custom models
- ✅ List all provisioned throughput models
- ✅ **Automatically generate a complete LiteLLM config** with ALL models
- ✅ Show you the exact commands to deploy

**Output example:**
```
========================================
AWS Bedrock Model Discovery Tool
========================================

✅ AWS Account: 123456789012

📋 Available Foundation Models (Nova family):
==========================================
✅ Amazon Nova Canvas 1.0
   ID: amazon.nova-canvas-v1:0
   Status: ACTIVE

🎨 Fine-tuned / Custom Models:
==========================================
✅ my-custom-nova-model
   ARN: arn:aws:bedrock:us-east-1:123456789012:custom-model/amazon.nova-canvas-v1:0/xxxxx
   Base: arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-canvas-v1:0
   Status: ACTIVE

⚡ Provisioned Throughput Models:
==========================================
✅ my-nova-provisioned
   ARN: arn:aws:bedrock:us-east-1:123456789012:provisioned-model/xxxxx
   Base Model: amazon.nova-canvas-v1:0
   Units: 2
   Status: InService
   Commitment: OneMonth

📝 Complete LiteLLM Configuration:
==========================================
✅ Generated configuration file: litellm-config-generated.yaml
```

### Step 2: Review Generated Configuration

The script creates `litellm-config-generated.yaml` with all your models:

```yaml
model_list:
  # Standard on-demand models
  - model_name: nova-canvas
    litellm_params:
      model: bedrock/amazon.nova-canvas-v1:0
      aws_region_name: us-east-1

  # Fine-tuned / Custom models
  - model_name: custom-my-custom-nova-model
    litellm_params:
      model: bedrock/arn:aws:bedrock:us-east-1:123456789012:custom-model/...
      aws_region_name: us-east-1

  # Provisioned throughput models
  - model_name: my-nova-provisioned
    litellm_params:
      model: bedrock/arn:aws:bedrock:us-east-1:123456789012:provisioned-model/...
      aws_region_name: us-east-1
```

### Step 3: Deploy to AWS

#### Option A: New Deployment

```bash
# Use the generated config
cp litellm-config-generated.yaml litellm-config.yaml

# Deploy stack
aws cloudformation create-stack \
  --stack-name bedrock-image-chat \
  --template-body file://bedrock-image-chat-stack.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

#### Option B: Update Existing Deployment

If you have a provisioned model ARN, update the stack:

```bash
aws cloudformation update-stack \
  --stack-name bedrock-image-chat \
  --template-body file://bedrock-image-chat-stack.yaml \
  --parameters \
    ParameterKey=ProvisionedModelArn,ParameterValue=arn:aws:bedrock:us-east-1:123456789012:provisioned-model/xxxxx \
    ParameterKey=ProjectName,UsePreviousValue=true \
    ParameterKey=Environment,UsePreviousValue=true \
    ParameterKey=DeploymentSize,UsePreviousValue=true \
    ParameterKey=BedrockRegion,UsePreviousValue=true \
    ParameterKey=EnabledModels,UsePreviousValue=true \
    ParameterKey=ACMCertificateArn,UsePreviousValue=true \
    ParameterKey=AllowedCIDR,UsePreviousValue=true \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### Step 4: Test Your Models

After deployment:

```bash
# Get the endpoint
ALB_URL=$(aws cloudformation describe-stacks \
  --stack-name bedrock-image-chat \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBEndpoint`].OutputValue' \
  --output text \
  --region us-east-1)

# Get API key
API_KEY=$(aws secretsmanager get-secret-value \
  --secret-id bedrock-image-chat/litellm-api-key \
  --query SecretString \
  --output text \
  --region us-east-1 | jq -r '.api_key')

# Test your fine-tuned model
curl -X POST "${ALB_URL}/v1/images/generations" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "model": "custom-my-custom-nova-model",
    "prompt": "A beautiful sunset over mountains",
    "n": 1,
    "size": "1024x1024"
  }'
```

## 🔧 Manual Configuration (Alternative)

If you prefer to add models manually instead of using the discovery script:

### 1. Find Your Model ARN

```bash
# List custom models
aws bedrock list-custom-models --region us-east-1

# List provisioned models
aws bedrock list-provisioned-model-throughputs --region us-east-1
```

### 2. Add to LiteLLM Config

Edit `infrastructure/litellm-config.yaml` or update the CloudFormation template's `LITELLM_CONFIG` environment variable:

```yaml
model_list:
  # Your fine-tuned model
  - model_name: my-custom-model
    litellm_params:
      model: bedrock/arn:aws:bedrock:us-east-1:123456789012:custom-model/amazon.nova-canvas-v1:0/xxxxx
      aws_region_name: us-east-1

  # Your provisioned model
  - model_name: my-provisioned-model
    litellm_params:
      model: bedrock/arn:aws:bedrock:us-east-1:123456789012:provisioned-model/yyyyy
      aws_region_name: us-east-1
```

### 3. Redeploy Stack

```bash
aws cloudformation update-stack \
  --stack-name bedrock-image-chat \
  --template-body file://bedrock-image-chat-stack.yaml \
  --use-previous-template \
  --parameters \
    ParameterKey=ProvisionedModelArn,ParameterValue=YOUR_ARN_HERE \
    ... (other parameters with UsePreviousValue=true) \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## 📚 Understanding Model Types

### Foundation Models (On-Demand)
- Standard AWS Bedrock models
- Pay per request
- No setup required
- **Example**: `amazon.nova-canvas-v1:0`

### Fine-Tuned / Custom Models
- Your customized version of a foundation model
- Trained on your data
- Higher accuracy for your use case
- **ARN format**: `arn:aws:bedrock:REGION:ACCOUNT:custom-model/BASE_MODEL/CUSTOM_ID`

### Provisioned Throughput Models
- Reserved capacity for any model (foundation or fine-tuned)
- Guaranteed performance
- Lower latency
- Fixed monthly cost
- **ARN format**: `arn:aws:bedrock:REGION:ACCOUNT:provisioned-model/PROVISIONED_ID`

## 🎯 Best Practices

1. **Use the Discovery Script**: Always run `./discover-models.sh` before deploying to ensure you have the latest models

2. **Name Your Models Clearly**: Use descriptive names like:
   - `nova-canvas-product-images` (fine-tuned for products)
   - `nova-canvas-high-throughput` (provisioned model)

3. **Test Locally First**: Update `docker-compose.yml` and test locally before deploying

4. **Monitor Costs**: Track usage in AWS Cost Explorer, especially for provisioned models

5. **Version Control**: Commit generated configs to git:
   ```bash
   git add litellm-config-generated.yaml
   git commit -m "Update model configuration with fine-tuned models"
   ```

## 🆘 Troubleshooting

### "Model not found" error

**Cause**: Model ARN incorrect or not accessible
**Solution**:
```bash
# Verify model exists and is active
./discover-models.sh us-east-1

# Check IAM permissions
aws bedrock get-custom-model --model-identifier YOUR_ARN --region us-east-1
```

### "Provisioning" status

**Cause**: Provisioned model not ready yet
**Solution**: Wait 10-15 minutes for provisioning to complete
```bash
aws bedrock get-provisioned-model-throughput \
  --provisioned-model-id YOUR_ID \
  --region us-east-1
```

### Image quality differs from expectations

**Cause**: Fine-tuned model may need prompt adjustments
**Solution**: Review fine-tuning data and adjust prompts based on training examples

## 📖 Additional Resources

- [AWS Bedrock Model Customization](https://docs.aws.amazon.com/bedrock/latest/userguide/custom-models.html)
- [Provisioned Throughput Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/prov-throughput.html)
- [LiteLLM Bedrock Documentation](https://docs.litellm.ai/docs/providers/bedrock)
- [Full Deployment Guide](infrastructure/README.md)
- [LiteLLM Configuration Details](infrastructure/litellm-config-guide.md)

## 💡 Quick Tips

- 🔍 Run `./discover-models.sh` regularly to see new models
- 📝 The generated config includes ALL models automatically
- 🚀 You can have multiple models active simultaneously
- 💰 Mix on-demand and provisioned models to optimize costs
- 🧪 Test models locally before production deployment

---

**Need Help?**
- Check [infrastructure/README.md](infrastructure/README.md) for full deployment guide
- Review [infrastructure/litellm-config-guide.md](infrastructure/litellm-config-guide.md) for advanced configuration
