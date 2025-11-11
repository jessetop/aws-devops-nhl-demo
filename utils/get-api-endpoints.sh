#!/bin/bash
# Get API endpoints for web frontend integration

STACK_NAME=${1:-"eks-nhl-test"}

echo "🔍 Getting API Endpoints..."
echo "=========================="

# NHL API Lambda endpoint (from SAM stack)
echo "📋 NHL API Service (Lambda):"
NHL_API_URL=$(aws cloudformation describe-stacks \
    --stack-name nhl-api-service \
    --query 'Stacks[0].Outputs[?OutputKey==`NhlApiUrl`].OutputValue' \
    --output text 2>/dev/null || echo "Stack not found")

if [ "$NHL_API_URL" != "Stack not found" ]; then
    echo "  ✅ $NHL_API_URL"
else
    echo "  ❌ NHL API Lambda not deployed yet"
    echo "     Deploy with: cd nhl-api-service && sam deploy"
fi

echo ""

# EKS Stats Processing Service endpoint
echo "🔧 Stats Processing Service (EKS):"
EKS_SERVICE_URL=$(kubectl get service stats-processing-service \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Service not found")

if [ "$EKS_SERVICE_URL" != "Service not found" ] && [ -n "$EKS_SERVICE_URL" ]; then
    echo "  ✅ http://$EKS_SERVICE_URL"
    echo "  Health check: http://$EKS_SERVICE_URL/health"
    echo "  Process stats: http://$EKS_SERVICE_URL/process-stats"
else
    echo "  ❌ EKS service not deployed or LoadBalancer not ready"
    echo "     Deploy with: ./linux/deploy-to-eks.sh"
    echo "     Check status: kubectl get services"
fi

echo ""
echo "🔧 Update web-frontend/app.py with these endpoints:"
echo "const NHL_API_ENDPOINT = '$NHL_API_URL';"
echo "const STATS_PROCESSING_ENDPOINT = 'http://$EKS_SERVICE_URL/process-stats';"