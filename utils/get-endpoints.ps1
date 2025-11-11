# Get service endpoints for the NHL Stats demo
param(
    [string]$StackName = "eks-nhl-test"
)

Write-Host "🔍 Finding service endpoints for stack: $StackName" -ForegroundColor Green

# Get NHL API Gateway URL
Write-Host "`n📡 NHL API Service (GitHub Actions + Lambda):" -ForegroundColor Yellow
try {
    $ApiId = aws apigateway get-rest-apis --query "items[?name=='$StackName-api'].id" --output text
    if ($ApiId) {
        $Region = aws configure get region
        $NhlApiUrl = "https://$ApiId.execute-api.$Region.amazonaws.com/prod/nhl-stats"
        Write-Host "✅ NHL API URL: $NhlApiUrl" -ForegroundColor Green
    } else {
        Write-Host "❌ NHL API Gateway not found" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error finding NHL API Gateway" -ForegroundColor Red
}

# Get EKS LoadBalancer URL
Write-Host "`n🚢 EKS Stats Processing Service:" -ForegroundColor Yellow
try {
    $LoadBalancerUrl = kubectl get service stats-processing-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
    if ($LoadBalancerUrl) {
        $EksUrl = "http://$LoadBalancerUrl/process-stats"
        Write-Host "✅ EKS Service URL: $EksUrl" -ForegroundColor Green
    } else {
        Write-Host "❌ EKS LoadBalancer not ready yet (may take a few minutes)" -ForegroundColor Red
        Write-Host "💡 Run: kubectl get services stats-processing-service" -ForegroundColor Cyan
    }
} catch {
    Write-Host "❌ Error accessing EKS cluster" -ForegroundColor Red
}

# Get Web Frontend URL
Write-Host "`n🌐 Web Frontend (Lambda):" -ForegroundColor Yellow
try {
    $WebApiId = aws apigateway get-rest-apis --query "items[?name=='$StackName-web-frontend'].id" --output text
    if ($WebApiId) {
        $Region = aws configure get region
        $WebUrl = "https://$WebApiId.execute-api.$Region.amazonaws.com/prod/"
        Write-Host "✅ Web Frontend URL: $WebUrl" -ForegroundColor Green
    } else {
        Write-Host "❌ Web Frontend API Gateway not found" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error finding Web Frontend API Gateway" -ForegroundColor Red
}

Write-Host "`n📝 Next steps:" -ForegroundColor Cyan
Write-Host "1. Update web-frontend/app.py with the actual URLs above" -ForegroundColor White
Write-Host "2. Commit and push to trigger the web frontend pipeline" -ForegroundColor White
Write-Host "3. Test the updated web frontend" -ForegroundColor White