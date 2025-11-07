# Bedrock Image Chat - CloudFormation Deployment Guide

Complete deployment guide for the AWS Bedrock Text-to-Image Chat Interface with support for fine-tuned Nova models and provisioned throughput.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Deployment](#detailed-deployment)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Provisioned Throughput Setup](#provisioned-throughput-setup)
- [Accessing the Application](#accessing-the-application)
- [Monitoring and Operations](#monitoring-and-operations)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)
- [Clean Up](#clean-up)

## 🏗️ Architecture Overview

The stack deploys:

- **VPC** with public and private subnets across 2 AZs
- **ECS Fargate** cluster running:
  - Open WebUI (chat interface)
  - LiteLLM Proxy (Bedrock integration with pre-configured on-demand models)
- **Application Load Balancer** for HTTPS access
- **EFS** for persistent storage
- **VPC Endpoints** for Bedrock, ECR, S3, and CloudWatch (no NAT Gateway needed)
- **IAM roles** with Bedrock permissions including provisioned throughput support

**Pre-configured Models (On-Demand):**
- ✅ Amazon Nova Canvas v1.0 (image generation)
- ✅ Claude 3.5 Sonnet v2 (text chat with streaming)
- ✅ Titan Image Generator V2 (image generation)

## ✅ Prerequisites

### 1. AWS Account Setup

- AWS account with appropriate permissions
- AWS CLI installed and configured
- Bedrock model access enabled in us-east-1

### 2. Enable Bedrock Model Access

```bash
# Check current model access
aws bedrock list-foundation-models \
  --region us-east-1 \
  --query 'modelSummaries[?contains(modelId, `nova`) || contains(modelId, `claude`)].{ID:modelId,Name:modelName,Status:modelLifecycle.status}' \
  --output table

# Request access via console if needed:
# AWS Console → Bedrock → Model access → Manage model access
# Enable: Amazon Nova Canvas, Claude 3.5 Sonnet, Titan Image Generator
```

### 3. Optional: ACM Certificate for HTTPS

For production deployments with custom domains:

```bash
# Request a certificate (if you have a domain)
aws acm request-certificate \
  --domain-name chat.yourdomain.com \
  --validation-method DNS \
  --region us-east-1

# Note the certificate ARN for deployment
```

### 4. Service Quotas

Verify you have sufficient quotas:

```bash
# Check ECS quotas
aws service-quotas get-service-quota \
  --service-code ecs \
  --quota-code L-3032A538 \
  --region us-east-1

# Check Bedrock quotas
aws service-quotas list-service-quotas \
  --service-code bedrock \
  --region us-east-1
```

## 🚀 Quick Start

> **Pre-configured with on-demand models!** Nova Canvas, Claude 3.5 Sonnet, and Titan Image are ready to use immediately after deployment. No manual model configuration needed.

### Option 1: Deploy with Default Settings

```bash
# Clone or navigate to the repository
cd infrastructure

# Validate the template
aws cloudformation validate-template \
  --template-body file://bedrock-image-chat-stack.yaml \
  --region us-east-1

# Deploy the stack
aws cloudformation create-stack \
  --stack-name bedrock-image-chat \
  --template-body file://bedrock-image-chat-stack.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1 \
  --tags Key=Project,Value=BedrockImageChat Key=Environment,Value=Production

# Monitor deployment (takes 15-20 minutes)
aws cloudformation wait stack-create-complete \
  --stack-name bedrock-image-chat \
  --region us-east-1

# Get the endpoint URL
aws cloudformation describe-stacks \
  --stack-name bedrock-image-chat \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBEndpoint`].OutputValue' \
  --output text \
  --region us-east-1
```

### Option 2: Deploy with Custom Parameters

```bash
# Create a custom parameters file
cat > my-parameters.json <<EOF
[
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "my-bedrock-chat"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "production"
  },
  {
    "ParameterKey": "DeploymentSize",
    "ParameterValue": "medium"
  },
  {
    "ParameterKey": "BedrockRegion",
    "ParameterValue": "us-east-1"
  },
  {
    "ParameterKey": "ACMCertificateArn",
    "ParameterValue": "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
  },
  {
    "ParameterKey": "AllowedCIDR",
    "ParameterValue": "10.0.0.0/8"
  }
]
EOF

# Deploy with custom parameters
aws cloudformation create-stack \
  --stack-name my-bedrock-chat \
  --template-body file://bedrock-image-chat-stack.yaml \
  --parameters file://my-parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## 📝 Detailed Deployment

### Step 1: Customize Parameters

Edit `parameters.json` to customize your deployment:

| Parameter | Description | Default | Notes |
|-----------|-------------|---------|-------|
| ProjectName | Resource prefix | bedrock-image-chat | Must be lowercase, alphanumeric |
| Environment | Environment name | production | development/staging/production |
| DeploymentSize | Resource allocation | small | small/medium/large |
| BedrockRegion | Bedrock API region | us-east-1 | Must have model access |
| ProvisionedModelArn | Provisioned model ARN | (empty) | Optional, for provisioned throughput |
| ACMCertificateArn | SSL certificate ARN | (empty) | Required for HTTPS |
| AllowedCIDR | IP access restriction | 0.0.0.0/0 | Restrict for security |

**Deployment Size Impact:**

| Size | Open WebUI | Tasks | Use Case |
|------|-----------|-------|----------|
| Small | 1 vCPU, 2GB | 1 | Development, <10 users |
| Medium | 2 vCPU, 4GB | 2 | Small teams, 10-30 users |
| Large | 4 vCPU, 8GB | 3 | Production, 30-100 users |

### Step 2: Pre-Deployment Validation

```bash
# Check if stack name is available
aws cloudformation describe-stacks \
  --stack-name bedrock-image-chat \
  --region us-east-1 2>&1 | grep -q "does not exist" && echo "Stack name available" || echo "Stack already exists"

# Validate template syntax
aws cloudformation validate-template \
  --template-body file://bedrock-image-chat-stack.yaml \
  --region us-east-1

# Estimate costs (optional)
# Use AWS Pricing Calculator or cost estimation tools
```

### Step 3: Deploy the Stack

```bash
# Create the stack
aws cloudformation create-stack \
  --stack-name bedrock-image-chat \
  --template-body file://bedrock-image-chat-stack.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1 \
  --tags \
    Key=Project,Value=BedrockImageChat \
    Key=Environment,Value=Production \
    Key=ManagedBy,Value=CloudFormation

# Watch deployment progress in real-time
aws cloudformation describe-stack-events \
  --stack-name bedrock-image-chat \
  --region us-east-1 \
  --query 'StackEvents[0:10].{Time:Timestamp,Status:ResourceStatus,Type:ResourceType,Reason:ResourceStatusReason}' \
  --output table

# Or use CloudFormation console:
# https://console.aws.amazon.com/cloudformation/home?region=us-east-1
```

### Step 4: Monitor Deployment

```bash
# Wait for completion (blocking)
aws cloudformation wait stack-create-complete \
  --stack-name bedrock-image-chat \
  --region us-east-1

# Check stack status
aws cloudformation describe-stacks \
  --stack-name bedrock-image-chat \
  --query 'Stacks[0].StackStatus' \
  --output text \
  --region us-east-1
```

**Expected Timeline:**
- VPC and networking: 2-3 minutes
- EFS and security groups: 1-2 minutes
- ECS cluster and tasks: 3-5 minutes
- ALB and health checks: 5-8 minutes
- **Total: 15-20 minutes**

## 🔧 Post-Deployment Configuration

### 1. Retrieve Deployment Information

```bash
# Get all stack outputs
aws cloudformation describe-stacks \
  --stack-name bedrock-image-chat \
  --query 'Stacks[0].Outputs' \
  --output table \
  --region us-east-1

# Get specific outputs
ALB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name bedrock-image-chat \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBEndpoint`].OutputValue' \
  --output text \
  --region us-east-1)

LITELLM_SECRET=$(aws cloudformation describe-stacks \
  --stack-name bedrock-image-chat \
  --query 'Stacks[0].Outputs[?OutputKey==`LiteLLMAPIKeySecretArn`].OutputValue' \
  --output text \
  --region us-east-1)

echo "Access your application at: $ALB_ENDPOINT"
```

### 2. Retrieve Secrets

```bash
# Get LiteLLM API key
LITELLM_API_KEY=$(aws secretsmanager get-secret-value \
  --secret-id bedrock-image-chat/litellm-api-key \
  --query SecretString \
  --output text \
  --region us-east-1 | jq -r '.api_key')

echo "LiteLLM API Key: $LITELLM_API_KEY"

# Get Open WebUI admin password
ADMIN_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id bedrock-image-chat/openwebui-admin \
  --query SecretString \
  --output text \
  --region us-east-1 | jq -r '.password')

echo "Admin Password: $ADMIN_PASSWORD"
```

### 3. Configure DNS (Optional)

If using a custom domain:

```bash
# Get ALB DNS name
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name bedrock-image-chat \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text \
  --region us-east-1)

# Create Route53 record (if using Route53)
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"CREATE\",
      \"ResourceRecordSet\": {
        \"Name\": \"chat.yourdomain.com\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$ALB_DNS\"}]
      }
    }]
  }"
```

## 🚄 Provisioned Throughput Setup (Optional)

> **Note:** The stack is pre-configured with **on-demand Bedrock models** and works out of the box. Provisioned throughput is **optional** and only needed for:
> - Fine-tuned custom models
> - Guaranteed capacity and lower latency
> - High-volume production workloads (>10,000 images/day)

For fine-tuned models or guaranteed performance, set up provisioned throughput:

### 1. Purchase Provisioned Throughput

```bash
# Create provisioned throughput for Nova Canvas
aws bedrock create-provisioned-model-throughput \
  --provisioned-model-name "my-nova-canvas-provisioned" \
  --model-id "amazon.nova-canvas-v1:0" \
  --model-units 1 \
  --commitment-duration "OneMonth" \
  --region us-east-1

# Wait for provisioning (10-15 minutes)
aws bedrock get-provisioned-model-throughput \
  --provisioned-model-id "YOUR_PROVISIONED_MODEL_ID" \
  --region us-east-1 \
  --query 'status'
```

### 2. Update Stack with Provisioned Model ARN

```bash
# Get provisioned model ARN
PROVISIONED_ARN=$(aws bedrock list-provisioned-model-throughputs \
  --region us-east-1 \
  --query 'provisionedModelSummaries[?provisionedModelName==`my-nova-canvas-provisioned`].provisionedModelArn' \
  --output text)

# Update parameters
cat > updated-parameters.json <<EOF
[
  {
    "ParameterKey": "ProvisionedModelArn",
    "ParameterValue": "$PROVISIONED_ARN"
  }
]
EOF

# Update stack
aws cloudformation update-stack \
  --stack-name bedrock-image-chat \
  --template-body file://bedrock-image-chat-stack.yaml \
  --parameters file://updated-parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### 3. Configure Model in LiteLLM

See the [LiteLLM Configuration Guide](./litellm-config-guide.md) for detailed instructions on configuring provisioned models.

## 🌐 Accessing the Application

### 1. Access Open WebUI

```bash
# Navigate to the ALB endpoint
open $ALB_ENDPOINT
# Or visit manually: http://your-alb-dns-name
```

### 2. First-Time Setup

1. **Create Admin Account**:
   - First user to register becomes admin
   - Use a strong password
   - Save credentials securely

2. **Models Pre-Configured** (Ready to Use):
   - ✅ **nova-canvas** - Amazon Nova Canvas (image generation)
   - ✅ **claude-sonnet** - Claude 3.5 Sonnet (text chat with streaming)

   All models are configured automatically and ready to use immediately!

3. **Test Image Generation**:
   - Create new chat
   - Type: "Generate an image of a sunset over mountains"
   - Wait ~10-15 seconds for image

### 3. Using the Chat Interface

**Text Chat:**
```
User: What are the best practices for prompt engineering?
```

**Image Generation:**
```
User: Generate an image of a futuristic city skyline at night with neon lights
```

**Image Analysis** (if using vision models):
```
User: [Upload image] What do you see in this image?
```

## 📊 Monitoring and Operations

### CloudWatch Logs

```bash
# View Open WebUI logs
aws logs tail /ecs/bedrock-image-chat \
  --follow \
  --filter-pattern "openwebui" \
  --region us-east-1

# View LiteLLM logs
aws logs tail /ecs/bedrock-image-chat \
  --follow \
  --filter-pattern "litellm" \
  --region us-east-1
```

### ECS Service Status

```bash
# Check service health
aws ecs describe-services \
  --cluster bedrock-image-chat-cluster \
  --services bedrock-image-chat-openwebui bedrock-image-chat-litellm \
  --region us-east-1 \
  --query 'services[].{Service:serviceName,Status:status,Running:runningCount,Desired:desiredCount}' \
  --output table

# Check task details
aws ecs list-tasks \
  --cluster bedrock-image-chat-cluster \
  --region us-east-1

aws ecs describe-tasks \
  --cluster bedrock-image-chat-cluster \
  --tasks TASK_ARN \
  --region us-east-1
```

### ALB Health Checks

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws cloudformation describe-stack-resources \
    --stack-name bedrock-image-chat \
    --logical-resource-id TargetGroup \
    --query 'StackResources[0].PhysicalResourceId' \
    --output text \
    --region us-east-1) \
  --region us-east-1
```

### CloudWatch Metrics Dashboard

Create a custom dashboard:

```bash
# Create dashboard JSON
cat > dashboard.json <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", {"stat": "Average"}],
          [".", "MemoryUtilization", {"stat": "Average"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "ECS Cluster Metrics"
      }
    }
  ]
}
EOF

# Create dashboard
aws cloudwatch put-dashboard \
  --dashboard-name bedrock-image-chat \
  --dashboard-body file://dashboard.json \
  --region us-east-1
```

## 💰 Cost Optimization

### Estimated Monthly Costs (us-east-1)

**Small Deployment (Default):**

| Service | Cost |
|---------|------|
| ALB | $16.20 |
| ECS Fargate (1 vCPU, 2GB, 1 task) | $29.50 |
| EFS (10GB) | $3.00 |
| VPC Endpoints (4 endpoints) | $28.80 |
| CloudWatch Logs | $5.00 |
| **Infrastructure Total** | **$82.50** |
| Bedrock API (1000 images) | $40-80 |
| **Grand Total** | **$122.50-162.50** |

### Cost Reduction Strategies

1. **Remove VPC Endpoints** (saves $28.80/month):
   - Add NAT Gateway instead (adds $32.40/month)
   - Net increase but simpler for some setups

2. **Use Fargate Spot** (saves ~70% on compute):
   ```bash
   # Update task definition to use Fargate Spot
   # Edit cloudformation template capacity provider strategy
   ```

3. **Scale Down During Off-Hours**:
   ```bash
   # Scale to 0 during nights
   aws ecs update-service \
     --cluster bedrock-image-chat-cluster \
     --service bedrock-image-chat-openwebui \
     --desired-count 0 \
     --region us-east-1

   # Scale back up
   aws ecs update-service \
     --cluster bedrock-image-chat-cluster \
     --service bedrock-image-chat-openwebui \
     --desired-count 1 \
     --region us-east-1
   ```

4. **EFS Lifecycle Policies**:
   - Already enabled: files transition to IA after 30 days
   - Saves 90% on infrequently accessed data

## 🔧 Troubleshooting

### Issue: Tasks Not Starting

**Symptoms:** ECS tasks in PENDING or STOPPED state

**Solutions:**
```bash
# Check task stopped reason
aws ecs describe-tasks \
  --cluster bedrock-image-chat-cluster \
  --tasks $(aws ecs list-tasks --cluster bedrock-image-chat-cluster --query 'taskArns[0]' --output text --region us-east-1) \
  --query 'tasks[0].stoppedReason' \
  --region us-east-1

# Common causes:
# 1. EFS mount failure - check security groups
# 2. Image pull failure - check VPC endpoints
# 3. Resource limits - check account quotas
```

### Issue: Cannot Access Application

**Symptoms:** ALB returns 503 or timeout

**Solutions:**
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN \
  --region us-east-1

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids $(aws cloudformation describe-stack-resources \
    --stack-name bedrock-image-chat \
    --logical-resource-id ALBSecurityGroup \
    --query 'StackResources[0].PhysicalResourceId' \
    --output text \
    --region us-east-1) \
  --region us-east-1
```

### Issue: Image Generation Fails

**Symptoms:** Text chat works, but image generation returns errors

**Solutions:**
```bash
# Check Bedrock model access
aws bedrock list-foundation-models \
  --region us-east-1 \
  --query 'modelSummaries[?contains(modelId, `nova`)]'

# Check IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn $(aws cloudformation describe-stack-resources \
    --stack-name bedrock-image-chat \
    --logical-resource-id ECSTaskRole \
    --query 'StackResources[0].PhysicalResourceId' \
    --output text \
    --region us-east-1) \
  --action-names bedrock:InvokeModel \
  --region us-east-1

# Check LiteLLM logs for errors
aws logs tail /ecs/bedrock-image-chat \
  --follow \
  --filter-pattern "ERROR" \
  --region us-east-1
```

### Issue: High Latency

**Symptoms:** Slow response times

**Solutions:**
```bash
# Check CPU/Memory utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=bedrock-image-chat-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region us-east-1

# Scale up if needed
aws ecs update-service \
  --cluster bedrock-image-chat-cluster \
  --service bedrock-image-chat-openwebui \
  --desired-count 2 \
  --region us-east-1
```

## 🧹 Clean Up

### Delete the Stack

```bash
# Delete the CloudFormation stack
aws cloudformation delete-stack \
  --stack-name bedrock-image-chat \
  --region us-east-1

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name bedrock-image-chat \
  --region us-east-1
```

### Delete Provisioned Throughput

```bash
# List provisioned models
aws bedrock list-provisioned-model-throughputs \
  --region us-east-1

# Delete provisioned throughput
aws bedrock delete-provisioned-model-throughput \
  --provisioned-model-id YOUR_PROVISIONED_MODEL_ID \
  --region us-east-1
```

### Manual Cleanup (if needed)

```bash
# Delete EFS backups
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name Default \
  --region us-east-1

# Empty CloudWatch logs
aws logs delete-log-group \
  --log-group-name /ecs/bedrock-image-chat \
  --region us-east-1

# Delete secrets
aws secretsmanager delete-secret \
  --secret-id bedrock-image-chat/litellm-api-key \
  --force-delete-without-recovery \
  --region us-east-1
```

## 📚 Additional Resources

- [CloudFormation Template](./bedrock-image-chat-stack.yaml)
- [LiteLLM Configuration Guide](./litellm-config-guide.md)
- [Parameters Reference](./parameters.json)
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [LiteLLM Documentation](https://docs.litellm.ai/)

## 🤝 Support

For issues and questions:
- Check the [Troubleshooting](#troubleshooting) section
- Review CloudWatch logs
- Consult AWS Bedrock documentation
- Open an issue in the repository

## 📄 License

See the LICENSE file in the repository root.
