#!/bin/bash
# Get service endpoints for the NHL Stats demo

STACK_NAME=${1:-eks-nhl-test}

echo "🔍 Finding service endpoints for stack: $STACK_NAME"

# Get NHL API Gateway URL
echo ""
echo "📡 NHL API Service (GitHub Actions + Lambda):"
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='$STACK_NAME-api'].id" --output text)
if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
    REGION=$(aws configure get region)
    NHL_API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/prod/nhl-stats"
    echo "✅ NHL API URL: $NHL_API_URL"
else
    echo "❌ NHL API Gateway not found"
fi

# Get EKS LoadBalancer URL
echo ""
echo "🚢 EKS Stats Processing Service:"
LOADBALANCER_URL=$(kubectl get service stats-processing-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$LOADBALANCER_URL" ]; then
    EKS_URL="http://$LOADBALANCER_URL/process-stats"
    echo "✅ EKS Service URL: $EKS_URL"
else
    echo "❌ EKS LoadBalancer not ready yet (may take a few minutes)"
    echo "💡 Run: kubectl get services stats-processing-service"
fi

# Get Web Frontend URL
echo ""
echo "🌐 Web Frontend (Lambda):"
WEB_API_ID=$(aws apigateway get-rest-apis --query "items[?name=='$STACK_NAME-web-frontend'].id" --output text)
if [ -n "$WEB_API_ID" ] && [ "$WEB_API_ID" != "None" ]; then
    REGION=$(aws configure get region)
    WEB_URL="https://$WEB_API_ID.execute-api.$REGION.amazonaws.com/prod/"
    echo "✅ Web Frontend URL: $WEB_URL"
else
    echo "❌ Web Frontend API Gateway not found"
fi

echo ""
echo "📝 Next steps:"
echo "1. Update web-frontend/app.py with the actual URLs above"
echo "2. Commit and push to trigger the web frontend pipeline"
echo "3. Test the updated web frontend"