# Requirements and Design Document
## Text-to-Image Chat Interface with AWS Bedrock
### CloudFormation Stack Implementation

**Document Version:** 1.0  
**Date:** November 2025  
**Status:** Final Design

---

## Executive Summary

This document outlines the requirements and design for a CloudFormation stack that deploys a minimal, production-ready text-to-image chat interface integrated with AWS Bedrock. Based on extensive research and validation, the recommended architecture uses **Open WebUI + LiteLLM Proxy** to provide both text chat and image generation capabilities through AWS Bedrock's foundation models.

**Key Finding:** The previously recommended Bedrock Access Gateway does NOT support image generation endpoints, making LiteLLM the required proxy solution for text-to-image workflows.

---

## 1. Business Requirements

### 1.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|---------|
| FR-001 | System must provide a web-based chat interface for text conversations | Critical | ✅ |
| FR-002 | System must generate images from text prompts using AWS Bedrock models | Critical | ✅ |
| FR-003 | Support for multiple AWS Bedrock text-to-image models (Nova Canvas, Stable Diffusion, Titan) | High | ✅ |
| FR-004 | Persistent storage of chat history and generated images | High | ✅ |
| FR-005 | User authentication and session management | High | ✅ |
| FR-006 | Real-time streaming of text responses | Medium | ✅ |
| FR-007 | Support for multimodal input (image analysis with vision models) | Medium | ✅ |
| FR-008 | Ability to save and download generated images | High | ✅ |

### 1.2 Non-Functional Requirements

| ID | Requirement | Target | Measurement |
|----|-------------|--------|-------------|
| NFR-001 | Response latency for text generation | < 2 seconds TTFT | CloudWatch metrics |
| NFR-002 | Image generation time | < 15 seconds | End-to-end timing |
| NFR-003 | System availability | 99.5% uptime | CloudWatch alarms |
| NFR-004 | Concurrent users | 10-50 users | Load testing |
| NFR-005 | Data encryption | At rest and in transit | AWS compliance |
| NFR-006 | Cost optimization | < $150/month base | AWS Cost Explorer |
| NFR-007 | Deployment time | < 30 minutes | CloudFormation events |
| NFR-008 | Auto-scaling capability | 1-10 containers | ECS metrics |

### 1.3 Constraints

- **Regional Limitation:** Must deploy in us-west-2 for full Stability AI model access
- **Model Access:** Requires pre-approved access to Bedrock models
- **Budget:** Minimize fixed infrastructure costs (serverless preferred)
- **Complexity:** Simple deployment suitable for teams without deep AWS expertise

---

## 2. Architecture Design

### 2.1 High-Level Architecture

```
┌─────────────────┐
│   CloudFront    │ (Optional CDN)
└────────┬────────┘
         │
┌────────▼────────┐
│  ALB (HTTPS)    │ Port 443 with ACM Certificate
└────────┬────────┘
         │
┌────────▼────────────────────────────┐
│        ECS Fargate Cluster          │
│  ┌──────────────┐  ┌─────────────┐ │
│  │  Open WebUI  │  │  LiteLLM    │ │
│  │  Container   │◄─►│   Proxy     │ │
│  └──────┬───────┘  └──────┬──────┘ │
└─────────┼─────────────────┼────────┘
          │                 │
     ┌────▼────┐      ┌─────▼──────┐
     │   EFS   │      │  AWS       │
     │ Storage │      │  Bedrock   │
     └─────────┘      └────────────┘
```

### 2.2 Component Architecture

#### 2.2.1 Networking Layer
- **VPC:** Custom VPC with DNS enabled (10.0.0.0/16)
- **Public Subnets:** 2 AZs for ALB (10.0.1.0/24, 10.0.2.0/24)
- **Private Subnets:** 2 AZs for ECS tasks (10.0.10.0/24, 10.0.11.0/24)
- **VPC Endpoints:** Bedrock, ECR, S3 (eliminates NAT Gateway costs)

#### 2.2.2 Compute Layer
- **ECS Cluster:** Fargate launch type for serverless containers
- **Open WebUI Service:** 1-3 tasks, 2 vCPU, 4GB RAM
- **LiteLLM Service:** 1-3 tasks, 1 vCPU, 2GB RAM
- **Service Discovery:** AWS Cloud Map for internal communication

#### 2.2.3 Storage Layer
- **EFS:** Persistent storage for chat history and configurations
- **Mount Point:** /app/backend/data for Open WebUI
- **Encryption:** AES-256 encryption at rest

#### 2.2.4 Security Layer
- **IAM Roles:** Task execution and task roles with minimal permissions
- **Security Groups:** Restrictive ingress/egress rules
- **Secrets Manager:** API keys and sensitive configuration

### 2.3 Supported AWS Bedrock Models

| Model | Model ID | Purpose | Region |
|-------|----------|---------|--------|
| Amazon Nova Canvas | amazon.nova-canvas-v1:0 | Primary image generation | us-east-1, us-west-2 |
| Stable Diffusion 3.5 Large | stability.stable-diffusion-3-5-large-v1:0 | High-quality images | us-west-2 |
| Stable Image Ultra | stability.stable-image-ultra-v1:0 | Photorealistic images | us-west-2 |
| Titan Image Generator V2 | amazon.titan-image-generator-v2:0 | Fast generation | us-east-1, us-west-2 |
| Claude 3.5 Sonnet | anthropic.claude-3-5-sonnet-20241022-v2:0 | Text conversations | Multiple regions |

---

## 3. CloudFormation Stack Design

### 3.1 Stack Parameters

```yaml
Parameters:
  ProjectName:
    Type: String
    Default: "bedrock-image-chat"
    Description: "Project name for resource tagging"
    
  DeploymentSize:
    Type: String
    Default: "small"
    AllowedValues: ["small", "medium", "large"]
    Description: "Deployment size affecting task count and resources"
    
  DomainName:
    Type: String
    Default: ""
    Description: "Optional custom domain name (leave empty for ALB DNS)"
    
  ACMCertificateArn:
    Type: String
    Default: ""
    Description: "ACM certificate ARN for HTTPS (required for production)"
    
  BedrockRegion:
    Type: String
    Default: "us-west-2"
    AllowedValues: ["us-east-1", "us-west-2", "eu-west-1", "ap-northeast-1"]
    Description: "AWS region for Bedrock model access"
    
  EnabledModels:
    Type: CommaDelimitedList
    Default: "nova-canvas,claude-sonnet,stable-diffusion"
    Description: "Comma-separated list of models to enable"
```

### 3.2 Stack Resources Structure

```yaml
Resources:
  # Networking Resources (10 resources)
  VPC:
    Type: AWS::EC2::VPC
  PublicSubnet1:
    Type: AWS::EC2::Subnet
  PublicSubnet2:
    Type: AWS::EC2::Subnet
  PrivateSubnet1:
    Type: AWS::EC2::Subnet
  PrivateSubnet2:
    Type: AWS::EC2::Subnet
  InternetGateway:
    Type: AWS::EC2::InternetGateway
  VPCGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
  RouteTablePublic:
    Type: AWS::EC2::RouteTable
  RouteTablePrivate:
    Type: AWS::EC2::RouteTable
  VPCEndpointBedrock:
    Type: AWS::EC2::VPCEndpoint
    
  # Security Groups (4 resources)
  ALBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
  ContainerSecurityGroup:
    Type: AWS::EC2::SecurityGroup
  EFSSecurityGroup:
    Type: AWS::EC2::SecurityGroup
  VPCEndpointSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    
  # IAM Roles (2 resources)
  ECSTaskExecutionRole:
    Type: AWS::IAM::Role
  ECSTaskRole:
    Type: AWS::IAM::Role
    
  # Storage (3 resources)
  EFSFileSystem:
    Type: AWS::EFS::FileSystem
  EFSMountTarget1:
    Type: AWS::EFS::MountTarget
  EFSMountTarget2:
    Type: AWS::EFS::MountTarget
    
  # ECS Resources (6 resources)
  ECSCluster:
    Type: AWS::ECS::Cluster
  OpenWebUITaskDefinition:
    Type: AWS::ECS::TaskDefinition
  LiteLLMTaskDefinition:
    Type: AWS::ECS::TaskDefinition
  OpenWebUIService:
    Type: AWS::ECS::Service
  LiteLLMService:
    Type: AWS::ECS::Service
  ServiceDiscoveryNamespace:
    Type: AWS::ServiceDiscovery::PrivateDnsNamespace
    
  # Load Balancer (4 resources)
  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
  TargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
  HTTPSListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
  HTTPListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    
  # Secrets (2 resources)
  LiteLLMAPIKey:
    Type: AWS::SecretsManager::Secret
  OpenWebUIAdminPassword:
    Type: AWS::SecretsManager::Secret
```

### 3.3 Critical Resource Configurations

#### 3.3.1 ECS Task Definition for Open WebUI

```yaml
OpenWebUITaskDefinition:
  Type: AWS::ECS::TaskDefinition
  Properties:
    Family: !Sub "${ProjectName}-openwebui"
    NetworkMode: awsvpc
    RequiresCompatibilities: [FARGATE]
    Cpu: !If [IsSmall, "1024", !If [IsMedium, "2048", "4096"]]
    Memory: !If [IsSmall, "2048", !If [IsMedium, "4096", "8192"]]
    ExecutionRoleArn: !Ref ECSTaskExecutionRole
    TaskRoleArn: !Ref ECSTaskRole
    ContainerDefinitions:
      - Name: openwebui
        Image: ghcr.io/open-webui/open-webui:latest
        Essential: true
        PortMappings:
          - ContainerPort: 8080
            Protocol: tcp
        Environment:
          - Name: OPENAI_API_BASE_URL
            Value: !Sub "http://litellm.${ServiceDiscoveryNamespace}:4000/v1"
          - Name: OPENAI_API_KEY
            Value: !Ref LiteLLMAPIKey
          - Name: WEBUI_AUTH
            Value: "True"
          - Name: WEBUI_NAME
            Value: "Bedrock Image Chat"
          - Name: ENABLE_IMAGE_GENERATION
            Value: "True"
        MountPoints:
          - SourceVolume: efs-storage
            ContainerPath: /app/backend/data
        LogConfiguration:
          LogDriver: awslogs
          Options:
            awslogs-group: !Ref LogGroup
            awslogs-region: !Ref AWS::Region
            awslogs-stream-prefix: openwebui
    Volumes:
      - Name: efs-storage
        EFSVolumeConfiguration:
          FilesystemId: !Ref EFSFileSystem
          TransitEncryption: ENABLED
```

#### 3.3.2 ECS Task Definition for LiteLLM Proxy

```yaml
LiteLLMTaskDefinition:
  Type: AWS::ECS::TaskDefinition
  Properties:
    Family: !Sub "${ProjectName}-litellm"
    NetworkMode: awsvpc
    RequiresCompatibilities: [FARGATE]
    Cpu: "512"
    Memory: "1024"
    ExecutionRoleArn: !Ref ECSTaskExecutionRole
    TaskRoleArn: !Ref ECSTaskRole
    ContainerDefinitions:
      - Name: litellm
        Image: ghcr.io/berriai/litellm:main-latest
        Essential: true
        PortMappings:
          - ContainerPort: 4000
            Protocol: tcp
        Environment:
          - Name: AWS_REGION_NAME
            Value: !Ref BedrockRegion
          - Name: LITELLM_MODE
            Value: "PROXY"
          - Name: LITELLM_CONFIG_YAML
            Value: |
              model_list:
                - model_name: nova-canvas
                  litellm_params:
                    model: bedrock/amazon.nova-canvas-v1:0
                    aws_region_name: ${AWS_REGION_NAME}
                - model_name: claude-sonnet
                  litellm_params:
                    model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
                    aws_region_name: ${AWS_REGION_NAME}
                - model_name: stable-diffusion
                  litellm_params:
                    model: bedrock/stability.stable-diffusion-3-5-large-v1:0
                    aws_region_name: ${AWS_REGION_NAME}
        LogConfiguration:
          LogDriver: awslogs
          Options:
            awslogs-group: !Ref LogGroup
            awslogs-region: !Ref AWS::Region
            awslogs-stream-prefix: litellm
```

#### 3.3.3 IAM Task Role for Bedrock Access

```yaml
ECSTaskRole:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Statement:
        - Effect: Allow
          Principal:
            Service: ecs-tasks.amazonaws.com
          Action: sts:AssumeRole
    Policies:
      - PolicyName: BedrockAccess
        PolicyDocument:
          Statement:
            - Effect: Allow
              Action:
                - bedrock:InvokeModel
                - bedrock:InvokeModelWithResponseStream
                - bedrock:ListFoundationModels
                - bedrock:GetFoundationModel
              Resource:
                - !Sub "arn:aws:bedrock:${BedrockRegion}::foundation-model/*"
      - PolicyName: EFSAccess
        PolicyDocument:
          Statement:
            - Effect: Allow
              Action:
                - elasticfilesystem:ClientMount
                - elasticfilesystem:ClientWrite
              Resource: !GetAtt EFSFileSystem.Arn
```

---

## 4. Implementation Guide

### 4.1 Pre-Deployment Checklist

| Step | Action | Validation |
|------|--------|------------|
| 1 | Enable Bedrock model access in target region | Console → Bedrock → Model access |
| 2 | Create or import ACM certificate for HTTPS | ACM Console → Request certificate |
| 3 | Configure AWS CLI with appropriate credentials | `aws sts get-caller-identity` |
| 4 | Select deployment region (recommend us-west-2) | Check model availability |
| 5 | Review cost estimates (~$75-150/month) | AWS Pricing Calculator |

### 4.2 Deployment Steps

```bash
# Step 1: Clone the CloudFormation template
git clone https://github.com/your-org/bedrock-image-chat-stack.git
cd bedrock-image-chat-stack

# Step 2: Validate the template
aws cloudformation validate-template \
  --template-body file://stack.yaml \
  --region us-west-2

# Step 3: Deploy the stack
aws cloudformation create-stack \
  --stack-name bedrock-image-chat \
  --template-body file://stack.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=my-image-chat \
    ParameterKey=DeploymentSize,ParameterValue=small \
    ParameterKey=BedrockRegion,ParameterValue=us-west-2 \
    ParameterKey=ACMCertificateArn,ParameterValue=arn:aws:acm:... \
  --capabilities CAPABILITY_IAM \
  --region us-west-2

# Step 4: Monitor deployment (15-20 minutes)
aws cloudformation wait stack-create-complete \
  --stack-name bedrock-image-chat \
  --region us-west-2

# Step 5: Get the ALB URL
aws cloudformation describe-stacks \
  --stack-name bedrock-image-chat \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBEndpoint`].OutputValue' \
  --output text \
  --region us-west-2
```

### 4.3 Post-Deployment Configuration

1. **Access the Web Interface**
   - Navigate to: `https://your-alb-url` or custom domain
   - First user registration becomes admin

2. **Configure Models in Open WebUI**
   - Settings → Models → Add Model
   - Model: `nova-canvas` for image generation
   - Model: `claude-sonnet` for text chat

3. **Test Image Generation**
   - New Chat → Type: "Generate an image of a sunset over mountains"
   - Verify image appears in ~10-15 seconds

4. **Configure Backup Strategy**
   - Enable EFS automatic backups
   - Schedule: Daily at 2 AM UTC
   - Retention: 7 days

### 4.4 Monitoring Setup

```yaml
# CloudWatch Alarms Configuration
Alarms:
  - Name: HighCPU
    Metric: AWS/ECS/CPUUtilization
    Threshold: 80%
    Period: 5 minutes
    
  - Name: HighMemory
    Metric: AWS/ECS/MemoryUtilization
    Threshold: 85%
    Period: 5 minutes
    
  - Name: TaskFailures
    Metric: AWS/ECS/TaskCount
    Statistic: RUNNING < 1
    Period: 1 minute
    
  - Name: ALBUnhealthyHosts
    Metric: AWS/ELB/UnHealthyHostCount
    Threshold: > 0
    Period: 2 minutes
```

---

## 5. Testing & Validation

### 5.1 Functional Testing

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Text Chat | Send "Hello" message | Receive response from Claude model |
| Image Generation | Request "Generate a cat image" | Image appears within 15 seconds |
| Persistence | Restart container, check history | Previous chats remain available |
| Multi-model | Switch between models | Each model responds appropriately |
| Download | Right-click generated image | Can save image locally |

### 5.2 Performance Testing

```bash
# Basic load test with Apache Bench
ab -n 100 -c 10 https://your-alb-url/api/chat

# Expected results:
# - 95th percentile < 2 seconds for text
# - No 5xx errors
# - Memory usage < 80%
```

### 5.3 Security Testing

- [ ] HTTPS enforced (HTTP redirects to HTTPS)
- [ ] Security headers present (HSTS, CSP)
- [ ] No exposed credentials in CloudWatch logs
- [ ] IAM roles follow least privilege
- [ ] VPC endpoints prevent internet exposure

---

## 6. Operational Procedures

### 6.1 Scaling Procedures

#### Manual Scaling
```bash
# Scale up during high load
aws ecs update-service \
  --cluster bedrock-image-chat \
  --service openwebui-service \
  --desired-count 3

# Scale down during low usage
aws ecs update-service \
  --cluster bedrock-image-chat \
  --service openwebui-service \
  --desired-count 1
```

#### Auto-Scaling Configuration
```yaml
AutoScalingTarget:
  Type: AWS::ApplicationAutoScaling::ScalableTarget
  Properties:
    ServiceNamespace: ecs
    ResourceId: !Sub "service/${ECSCluster}/openwebui-service"
    ScalableDimension: ecs:service:DesiredCount
    MinCapacity: 1
    MaxCapacity: 10
    RoleARN: !Sub "arn:aws:iam::${AWS::AccountId}:role/ecsAutoscaleRole"

AutoScalingPolicy:
  Type: AWS::ApplicationAutoScaling::ScalingPolicy
  Properties:
    PolicyName: cpu-scaling
    ServiceNamespace: ecs
    ResourceId: !Sub "service/${ECSCluster}/openwebui-service"
    ScalableDimension: ecs:service:DesiredCount
    PolicyType: TargetTrackingScaling
    TargetTrackingScalingPolicyConfiguration:
      PredefinedMetricSpecification:
        PredefinedMetricType: ECSServiceAverageCPUUtilization
      TargetValue: 70
```

### 6.2 Backup & Recovery

#### Daily Backup Script
```bash
#!/bin/bash
# backup-efs.sh

# Variables
EFS_ID="fs-xxxxxxxxx"
BACKUP_BUCKET="s3://my-backups/bedrock-chat"
DATE=$(date +%Y%m%d)

# Create EFS backup
aws backup start-backup-job \
  --backup-vault-name Default \
  --resource-arn "arn:aws:elasticfilesystem:${REGION}:${ACCOUNT}:file-system/${EFS_ID}" \
  --iam-role-arn "arn:aws:iam::${ACCOUNT}:role/aws-backup-role"

# Export chat logs to S3
aws logs create-export-task \
  --log-group-name /ecs/bedrock-image-chat \
  --from $(($(date +%s -d "yesterday") * 1000)) \
  --to $(($(date +%s) * 1000)) \
  --destination "${BACKUP_BUCKET}/logs/${DATE}"
```

### 6.3 Troubleshooting Guide

| Issue | Symptoms | Resolution |
|-------|----------|------------|
| Container won't start | ECS task stops immediately | Check CloudWatch logs, verify image exists |
| Can't generate images | Text works, images fail | Verify Bedrock model access, check IAM permissions |
| Configuration lost | Settings reset after restart | Use environment variables, not UI config |
| High latency | Slow responses | Check task CPU/memory, enable auto-scaling |
| EFS mount failure | "Failed to mount" errors | Verify security groups allow NFS (2049) |

---

## 7. Cost Analysis

### 7.1 Monthly Cost Breakdown (Minimal Setup)

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| ALB | 1 ALB, 730 hours | $16.20 |
| ECS Fargate | 2 vCPU, 4GB RAM, 1 task | $29.50 |
| EFS | 10GB storage | $3.00 |
| VPC Endpoints | 3 endpoints (Bedrock, ECR, S3) | $21.60 |
| CloudWatch | Logs, metrics, alarms | $5.00 |
| **Infrastructure Total** | | **$75.30** |
| Bedrock Usage | ~1000 images/month | $20-50 |
| **Total Estimate** | | **$95-125** |

### 7.2 Cost Optimization Options

1. **Remove VPC Endpoints** (-$21.60/month)
   - Use NAT Gateway instead (+$32/month)
   - Net increase but simpler setup

2. **Use Lambda Function URL** (-$16.20/month)
   - Replace ALB with Lambda
   - Higher latency but lower cost

3. **Fargate Spot** (-70% on Fargate costs)
   - Accept interruptions
   - Good for development/testing

4. **Reserved Capacity** (-30-50% on Fargate)
   - 1-year commitment
   - Predictable workloads only

---

## 8. Disaster Recovery

### 8.1 RTO/RPO Targets

- **RTO (Recovery Time Objective):** 30 minutes
- **RPO (Recovery Point Objective):** 24 hours
- **Backup Retention:** 7 days
- **Cross-Region Backup:** Optional (additional cost)

### 8.2 DR Procedures

#### Stack Recreation
```bash
# In case of complete failure, redeploy from scratch
aws cloudformation create-stack \
  --stack-name bedrock-image-chat-dr \
  --template-body file://stack.yaml \
  --parameters file://last-known-good-params.json \
  --capabilities CAPABILITY_IAM

# Restore EFS from backup
aws backup start-restore-job \
  --recovery-point-arn "arn:aws:backup:..." \
  --iam-role-arn "arn:aws:iam::..." \
  --metadata "fileSystemId=${NEW_EFS_ID}"
```

---

## 9. Security Considerations

### 9.1 Security Controls

| Control | Implementation | Compliance |
|---------|---------------|------------|
| Encryption at Rest | EFS with KMS | ✅ HIPAA, PCI |
| Encryption in Transit | TLS 1.3 on ALB | ✅ HIPAA, PCI |
| Network Isolation | Private subnets | ✅ SOC 2 |
| IAM Least Privilege | Scoped policies | ✅ ISO 27001 |
| Secrets Management | AWS Secrets Manager | ✅ All |
| Audit Logging | CloudTrail enabled | ✅ All |
| Vulnerability Scanning | ECR scanning | ✅ Best Practice |

### 9.2 Security Hardening Checklist

- [ ] Enable WAF on ALB with rate limiting
- [ ] Configure security groups with minimal access
- [ ] Enable GuardDuty for threat detection
- [ ] Set up AWS Config for compliance monitoring
- [ ] Enable VPC Flow Logs for network analysis
- [ ] Rotate API keys quarterly
- [ ] Review IAM permissions monthly
- [ ] Scan container images for vulnerabilities

---

## 10. Future Enhancements

### Phase 2 (3-6 months)
- Multi-user tenancy with organizations
- RAG pipeline with Amazon Kendra
- Custom model fine-tuning interface
- Advanced prompt templates library
- Batch image generation capability

### Phase 3 (6-12 months)
- Multi-region deployment for HA
- Redis cache for improved performance
- GraphQL API for mobile apps
- Webhook integrations (Slack, Teams)
- Cost allocation by user/department

---

## Appendices

### A. Environment Variables Reference

| Variable | Service | Default | Description |
|----------|---------|---------|-------------|
| OPENAI_API_BASE_URL | OpenWebUI | http://litellm:4000/v1 | LiteLLM proxy endpoint |
| OPENAI_API_KEY | OpenWebUI | (from Secrets) | Authentication key |
| AWS_REGION_NAME | LiteLLM | us-west-2 | Bedrock region |
| LITELLM_MODE | LiteLLM | PROXY | Operation mode |
| WEBUI_AUTH | OpenWebUI | True | Enable authentication |
| ENABLE_IMAGE_GENERATION | OpenWebUI | True | Enable image features |

### B. Model Pricing Reference (as of Nov 2025)

| Model | Input (per 1K tokens) | Output (per 1K tokens) | Image Generation |
|-------|----------------------|------------------------|------------------|
| Claude 3.5 Sonnet | $0.003 | $0.015 | N/A |
| Nova Canvas | N/A | N/A | $0.04/image |
| SD 3.5 Large | N/A | N/A | $0.04/image |
| Stable Image Ultra | N/A | N/A | $0.08/image |
| Titan Image V2 | N/A | N/A | $0.01/image |

### C. Useful Commands

```bash
# View ECS service logs
aws logs tail /ecs/bedrock-image-chat --follow

# Check task status
aws ecs describe-tasks \
  --cluster bedrock-image-chat \
  --tasks $(aws ecs list-tasks --cluster bedrock-image-chat --query 'taskArns[0]' --output text)

# Update container image
aws ecs update-service \
  --cluster bedrock-image-chat \
  --service openwebui-service \
  --force-new-deployment

# Check Bedrock model access
aws bedrock list-foundation-models \
  --region us-west-2 \
  --query 'modelSummaries[?contains(modelId, `stability`) || contains(modelId, `nova`) || contains(modelId, `titan`)]'
```

---

## Document Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Technical Lead | | | |
| DevOps Lead | | | |
| Security Officer | | | |
| Project Manager | | | |

**Next Review Date:** February 2026

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Nov 2025 | Initial | Initial requirements and design |
| | | | |
