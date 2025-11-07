# Bedrock Image Chat - Nova Canvas Integration

Production-ready text-to-image chat interface powered by AWS Bedrock Nova Canvas with support for on-demand, fine-tuned, and provisioned throughput models.

## ✨ Features

- 🎨 **Image Generation**: Amazon Nova Canvas
- 💬 **Text Chat**: Claude 3.5 Sonnet with streaming
- 🔧 **Fine-Tuned Models**: Easy discovery and integration of custom models
- ⚡ **Provisioned Throughput**: Support for guaranteed capacity models
- 🏗️ **Production Ready**: Complete CloudFormation deployment
- 💰 **Cost Optimized**: VPC endpoints, no NAT Gateway needed
- 🔒 **Secure**: IAM roles, VPC isolation, encrypted storage

## 🚀 Quick Start

### Option 1: Deploy Pre-configured (On-Demand Models)

```bash
cd infrastructure

# Deploy with default on-demand models (Nova Canvas, Claude, Titan)
aws cloudformation create-stack \
  --stack-name bedrock-image-chat \
  --template-body file://bedrock-image-chat-stack.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Wait for completion (15-20 minutes)
aws cloudformation wait stack-create-complete \
  --stack-name bedrock-image-chat \
  --region us-east-1
```

### Option 2: Deploy with Fine-Tuned Models

See **[FINE-TUNED-MODELS-GUIDE.md](docs/FINE-TUNED-MODELS-GUIDE.md)** for the 5-minute quick start!

```bash
# Discover all your models (fine-tuned, provisioned, on-demand)
cd infrastructure
./discover-models.sh us-east-1

# It generates a complete config automatically!
cp litellm-config-generated.yaml litellm-config.yaml

# Deploy (commands shown in script output)
```

### Option 3: Local Testing

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Edit .env and add your credentials:
#    - POSTGRE_PASSWORD (any secure password)
#    - AWS_BEARER_TOKEN_BEDROCK (from AWS Console)

# 3. Load environment and test
source .env
./test-local.sh

# Access at http://localhost:8080
```

## 📋 Pre-configured Models

The deployment includes these models by default:

- ✅ **nova-canvas** - Amazon Nova Canvas v1.0 (image generation)
- ✅ **claude-sonnet** - Claude 3.5 Sonnet v2 (text chat with streaming)

## 🎯 Fine-Tuned & Custom Models

### Quick Discovery Tool

Use the included discovery script to automatically find and configure ALL your models:

```bash
cd infrastructure
./discover-models.sh us-east-1
```

This script will:
- ✅ List all foundation models
- ✅ List all fine-tuned/custom models
- ✅ List all provisioned throughput models
- ✅ **Auto-generate complete LiteLLM config**
- ✅ Show exact deployment commands

**For complete guide**: See [FINE-TUNED-MODELS-GUIDE.md](docs/FINE-TUNED-MODELS-GUIDE.md)

## 📁 Repository Structure

```
nova-canvas-chat/
├── README.md                           # This file
├── docker-compose.yml                  # Local testing environment
├── litellm-config.yaml                 # Model configuration
├── test-local.sh                       # Local testing script
├── docs/
│   ├── FINE-TUNED-MODELS-GUIDE.md     # Quick start for custom models ⭐
│   └── LOCAL-TESTING-RESULTS.md        # Test validation report
└── infrastructure/
    ├── bedrock-image-chat-stack.yaml   # CloudFormation template (30KB)
    ├── parameters.json                 # Deployment parameters
    ├── discover-models.sh              # Model discovery tool ⭐
    ├── litellm-config-guide.md        # Advanced configuration
    └── README.md                       # Deployment guide
```

## 💰 Cost Estimates

### Monthly Costs (us-east-1)

**Small Deployment (Default)**:
- Infrastructure: ~$82/month
- Bedrock on-demand: ~$0.04/image
  - 1,000 images = $40
  - 2,500 images = $100
- **Total**: ~$122-182/month

**With Provisioned Throughput**:
- Add ~$4,380/month per model unit
- Commitment discounts: 30-50% (6-12 month terms)

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [FINE-TUNED-MODELS-GUIDE.md](docs/FINE-TUNED-MODELS-GUIDE.md) | **⭐ Quick start for adding custom models (5 min)** |
| [IMAGE-GENERATION-CONFIG.md](docs/IMAGE-GENERATION-CONFIG.md) | **🎨 Image generation configuration & troubleshooting** |
| [BEDROCK-API-KEYS.md](docs/BEDROCK-API-KEYS.md) | **🔑 AWS Bedrock API Keys authentication guide** |
| [infrastructure/README.md](infrastructure/README.md) | Complete deployment guide |
| [infrastructure/litellm-config-guide.md](infrastructure/litellm-config-guide.md) | Advanced LiteLLM configuration |
| [LOCAL-TESTING-RESULTS.md](docs/LOCAL-TESTING-RESULTS.md) | Validation and test results |

## 🔧 Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS Authentication** - Choose one method:

   **Option A: Bedrock API Keys (Recommended for quick start)**
   ```bash
   # Generate at: https://console.aws.amazon.com/bedrock/api-keys
   # Then set environment variable:
   export AWS_BEARER_TOKEN_BEDROCK=your_api_key_here
   ```

   **Option B: IAM Credentials (Traditional method)**
   ```bash
   aws configure
   ```

3. **Bedrock Model Access** enabled in us-east-1
   ```bash
   # Check access
   aws bedrock list-foundation-models --region us-east-1
   ```
4. **Docker** (for local testing)

## 🏗️ Architecture

**Key Components**:
- **ECS Fargate**: Serverless container orchestration
- **Open WebUI**: Modern chat interface
- **LiteLLM Proxy**: Universal AI model gateway
- **EFS**: Persistent storage for chat history
- **ALB**: Load balancing and HTTPS termination
- **VPC Endpoints**: Cost-optimized networking (no NAT Gateway)

**Security**:
- ✅ Private subnets for containers
- ✅ IAM roles with least privilege
- ✅ EFS encryption at rest
- ✅ TLS 1.3 for HTTPS
- ✅ Secrets Manager for credentials

## 🧪 Testing

### Local Testing (Validated ✅)

```bash
# Start services
./test-local.sh

# Services run at:
# - Open WebUI: http://localhost:8080
# - LiteLLM API: http://localhost:4000

# Test image generation
curl -X POST 'http://localhost:4000/v1/images/generations' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-test-1234567890' \
  -d '{
    "model": "nova-canvas",
    "prompt": "A serene mountain landscape at sunset",
    "n": 1
  }'
```

Results: See [LOCAL-TESTING-RESULTS.md](docs/LOCAL-TESTING-RESULTS.md)

## 🚨 Common Issues & Solutions

### Issue: Images not generating in Open WebUI

**Root Causes**:
1. Open WebUI doesn't know which model to use
2. Nova Canvas doesn't support streaming

**Solution**: Verify these configurations are set correctly

```bash
# In docker-compose.yml
IMAGE_GENERATION_MODEL=nova-canvas  # ← Must be set!

# In litellm-config.yaml
stream: false  # ← Required for image models
```

**Quick Fix**:
```bash
# Check if config is correct
docker exec openwebui env | grep IMAGE_GENERATION_MODEL

# If missing, it's already fixed in latest version - just restart:
docker compose down && docker compose up -d
```

See [IMAGE-GENERATION-CONFIG.md](docs/IMAGE-GENERATION-CONFIG.md) for detailed troubleshooting.

### Issue: Can't find my fine-tuned model

**Solution**: Run the discovery script
```bash
cd infrastructure
./discover-models.sh us-east-1
```

### Issue: Provisioned model shows "Provisioning" status

**Solution**: Wait 10-15 minutes for provisioning to complete
```bash
aws bedrock get-provisioned-model-throughput \
  --provisioned-model-id YOUR_ID \
  --region us-east-1
```

### Issue: "Model not found" error

**Solution**: Check model access and ARN
```bash
# Verify model
aws bedrock get-custom-model \
  --model-identifier YOUR_ARN \
  --region us-east-1

# Check IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn YOUR_TASK_ROLE_ARN \
  --action-names bedrock:InvokeModel
```

## 🤝 Contributing

This is a production-ready template for AWS Bedrock Nova Canvas deployments. Feel free to:
- Fork and customize for your needs
- Submit issues for bugs or questions
- Share improvements via pull requests

## 📄 License

See [LICENSE](LICENSE) file.

## 🔗 Resources

- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Nova Canvas Model Card](https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-nova-canvas.html)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Open WebUI Documentation](https://docs.openwebui.com/)

## ⭐ Quick Links

- **Add Fine-Tuned Models**: [FINE-TUNED-MODELS-GUIDE.md](docs/FINE-TUNED-MODELS-GUIDE.md)
- **Full Deployment Guide**: [infrastructure/README.md](infrastructure/README.md)
- **Model Discovery Tool**: `infrastructure/discover-models.sh`
- **Local Testing**: `./test-local.sh`

---

**Ready to deploy?** Start with [FINE-TUNED-MODELS-GUIDE.md](docs/FINE-TUNED-MODELS-GUIDE.md) or jump directly to `infrastructure/README.md`!
