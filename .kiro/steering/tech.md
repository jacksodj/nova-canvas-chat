# Technology Stack

## Architecture
- **Container Orchestration**: AWS ECS Fargate (serverless containers)
- **Web Interface**: Open WebUI (ghcr.io/open-webui/open-webui:latest)
- **AI Proxy**: LiteLLM (ghcr.io/berriai/litellm:main-latest)
- **Load Balancer**: AWS Application Load Balancer with HTTPS
- **Storage**: AWS EFS for persistent chat history and configurations
- **Networking**: Custom VPC with VPC endpoints (no NAT Gateway)

## AWS Services
- **AI/ML**: AWS Bedrock (Nova Canvas, Claude 3.5 Sonnet, Titan Image)
- **Compute**: ECS Fargate
- **Storage**: EFS with encryption at rest
- **Security**: IAM roles, Secrets Manager, Security Groups
- **Monitoring**: CloudWatch Logs, Metrics, Alarms
- **DNS/SSL**: Route53, ACM certificates

## Infrastructure as Code
- **Primary**: CloudFormation templates (`infrastructure/bedrock-image-chat-stack.yaml`)
- **Parameters**: JSON configuration files (`infrastructure/parameters.json`)
- **Region**: Primarily us-east-1 (some models require us-west-2)

## Local Development
- **Container Runtime**: Docker Compose
- **Configuration**: `docker-compose.yml` and `litellm-config.yaml`
- **Testing Script**: `test-local.sh` for automated local setup

## Common Commands

### Local Development
```bash
# Start local environment
./test-local.sh

# View logs
docker compose logs -f

# Stop services
docker compose down
```

### AWS Deployment
```bash
# Deploy stack
aws cloudformation create-stack \
  --stack-name bedrock-image-chat \
  --template-body file://bedrock-image-chat-stack.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Monitor deployment
aws cloudformation wait stack-create-complete \
  --stack-name bedrock-image-chat \
  --region us-east-1

# Get endpoint URL
aws cloudformation describe-stacks \
  --stack-name bedrock-image-chat \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBEndpoint`].OutputValue' \
  --output text \
  --region us-east-1
```

### Model Discovery
```bash
# Discover all available models (fine-tuned, provisioned, on-demand)
cd infrastructure
./discover-models.sh us-east-1

# Use generated configuration
cp litellm-config-generated.yaml litellm-config.yaml
```

### Monitoring
```bash
# View ECS logs
aws logs tail /ecs/bedrock-image-chat --follow --region us-east-1

# Check service health
aws ecs describe-services \
  --cluster bedrock-image-chat-cluster \
  --services bedrock-image-chat-openwebui \
  --region us-east-1
```

## Configuration Files
- **LiteLLM Config**: `litellm-config.yaml` - Model definitions and proxy settings
- **Docker Compose**: `docker-compose.yml` - Local development environment
- **CloudFormation**: `infrastructure/bedrock-image-chat-stack.yaml` - AWS infrastructure
- **Parameters**: `infrastructure/parameters.json` - Deployment configuration