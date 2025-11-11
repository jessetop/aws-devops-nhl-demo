# Get API endpoints for web frontend integration
param([string]$StackName = "eks-nhl-test")

Write-Host "🔍 Getting API Endpoints..." -ForegroundColor Green
Write-Host "=========================="

# NHL API Lambda endpoint (from SAM stack)
Write-Host "📋 NHL API Service (Lambda):" -ForegroundColor Yellow
try {
    $nhlApiUrl = aws cloudformation describe-stacks --stack-name nhl-api-service --query 'Stacks[0].Outputs[?OutputKey==`NhlApiUrl`].OutputValue' --output text 2>$null
    if ($nhlApiUrl -and $nhlApiUrl -ne "None") {
        Write-Host "  ✅ $nhlApiUrl" -ForegroundColor Green
    } else {
        Write-Host "  ❌ NHL API Lambda not deployed yet" -ForegroundColor Red
        Write-Host "     Deploy with: cd nhl-api-service && sam deploy" -ForegroundColor White
    }
}
catch {
    Write-Host "  ❌ NHL API Lambda not deployed yet" -ForegroundColor Red
    Write-Host "     Deploy with: cd nhl-api-service && sam deploy" -ForegroundColor White
}

Write-Host ""

# EKS Stats Processing Service endpoint
Write-Host "🔧 Stats Processing Service (EKS):" -ForegroundColor Yellow
try {
    $eksServiceUrl = kubectl get service stats-processing-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
    if ($eksServiceUrl) {
        Write-Host "  ✅ http://$eksServiceUrl" -ForegroundColor Green
        Write-Host "  Health check: http://$eksServiceUrl/health" -ForegroundColor White
        Write-Host "  Process stats: http://$eksServiceUrl/process-stats" -ForegroundColor White
    } else {
        Write-Host "  ❌ EKS service not deployed or LoadBalancer not ready" -ForegroundColor Red
        Write-Host "     Deploy with: .\linux\deploy-to-eks.sh" -ForegroundColor White
        Write-Host "     Check status: kubectl get services" -ForegroundColor White
    }
}
catch {
    Write-Host "  ❌ EKS service not deployed or LoadBalancer not ready" -ForegroundColor Red
    Write-Host "     Deploy with: .\linux\deploy-to-eks.sh" -ForegroundColor White
    Write-Host "     Check status: kubectl get services" -ForegroundColor White
}

Write-Host ""
Write-Host "🔧 Update web-frontend/app.py with these endpoints:" -ForegroundColor Green
Write-Host "const NHL_API_ENDPOINT = '$nhlApiUrl';" -ForegroundColor White
Write-Host "const STATS_PROCESSING_ENDPOINT = 'http://$eksServiceUrl/process-stats';" -ForegroundColor White