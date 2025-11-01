#!/bin/bash
set -e

echo "🧪 Bedrock Image Chat - Local Testing Script"
echo "=============================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker Desktop."
    exit 1
fi
echo "✅ Docker is installed"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available. Please update Docker Desktop."
    exit 1
fi
echo "✅ Docker Compose is available"

# Check AWS credentials
if [ ! -f ~/.aws/credentials ] && [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "❌ AWS credentials not found. Please configure AWS CLI:"
    echo "   aws configure"
    exit 1
fi
echo "✅ AWS credentials found"

# Check AWS region
AWS_REGION=${AWS_REGION:-us-east-1}
echo "✅ Using AWS region: $AWS_REGION"

# Verify Bedrock access
echo ""
echo "Verifying Bedrock model access..."
if aws bedrock list-foundation-models --region us-east-1 --query 'modelSummaries[?modelId==`amazon.nova-canvas-v1:0`]' --output text &> /dev/null; then
    echo "✅ Bedrock access verified"
else
    echo "⚠️  Warning: Could not verify Bedrock access. Make sure you have:"
    echo "   1. Enabled model access in AWS Bedrock console"
    echo "   2. Configured AWS credentials with appropriate permissions"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "Starting services..."
echo "==================="

# Stop any existing containers
docker compose down -v 2>/dev/null || true

# Start services
docker compose up -d

echo ""
echo "Waiting for services to be healthy..."
sleep 5

# Wait for LiteLLM
echo -n "⏳ Waiting for LiteLLM Proxy"
for i in {1..30}; do
    if curl -s http://localhost:4000/health > /dev/null 2>&1; then
        echo " ✅"
        break
    fi
    echo -n "."
    sleep 2
done

# Wait for Open WebUI
echo -n "⏳ Waiting for Open WebUI"
for i in {1..30}; do
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo " ✅"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo "=============================================="
echo "🎉 Services are ready!"
echo "=============================================="
echo ""
echo "📊 Service URLs:"
echo "   - Open WebUI:     http://localhost:8080"
echo "   - LiteLLM Proxy:  http://localhost:4000"
echo ""
echo "🔑 Test Credentials:"
echo "   - API Key: sk-test-1234567890"
echo ""
echo "🧪 Quick Tests:"
echo ""
echo "1. List available models:"
echo "   curl http://localhost:4000/v1/models -H 'Authorization: Bearer sk-test-1234567890'"
echo ""
echo "2. Test text generation:"
echo "   curl -X POST http://localhost:4000/v1/chat/completions \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -H 'Authorization: Bearer sk-test-1234567890' \\"
echo "     -d '{\"model\": \"claude-sonnet\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
echo ""
echo "3. Test image generation:"
echo "   curl -X POST http://localhost:4000/v1/images/generations \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -H 'Authorization: Bearer sk-test-1234567890' \\"
echo "     -d '{\"model\": \"nova-canvas\", \"prompt\": \"A sunset over mountains\", \"n\": 1}'"
echo ""
echo "📱 Open your browser to http://localhost:8080 to use the web interface!"
echo ""
echo "📋 View logs:"
echo "   docker compose logs -f"
echo ""
echo "🛑 Stop services:"
echo "   docker compose down"
echo ""
