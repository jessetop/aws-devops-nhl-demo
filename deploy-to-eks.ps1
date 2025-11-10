# Deploy stats processing service to EKS - Run after infrastructure setup
param(
    [string]$Region = "us-east-1",
    [string]$ClusterName = "nhl-stats-cluster"
)

Write-Host "🚀 Deploying to EKS..." -ForegroundColor Green

# Update kubeconfig
Write-Host "Updating kubeconfig..." -ForegroundColor Yellow
aws eks update-kubeconfig --region $Region --name $ClusterName

# Get ECR repository URI
$EcrUri = aws cloudformation describe-stacks `
    --stack-name nhl-stats-codepipeline `
    --query 'Stacks[0].Outputs[?OutputKey==`StatsProcessingECR`].OutputValue' `
    --output text

# Update deployment with correct ECR URI
$AccountId = aws sts get-caller-identity --query Account --output text
(Get-Content stats-processing-service/k8s-deployment.yaml) `
    -replace 'ACCOUNT_ID', $AccountId `
    -replace 'REGION', $Region | Set-Content stats-processing-service/k8s-deployment.yaml

# Deploy to EKS
Write-Host "Deploying to Kubernetes..." -ForegroundColor Yellow
kubectl apply -f stats-processing-service/k8s-deployment.yaml

Write-Host "✅ EKS deployment complete!" -ForegroundColor Green
Write-Host "Check status with: kubectl get pods" -ForegroundColor Cyan