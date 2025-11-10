# NHL Stats DevOps Demo Deployment Script

param(
    [string]$GitHubRepo = "your-username/aws-devops-pipeline-demo",
    [string]$GitHubToken = "",
    [string]$Region = "us-east-1"
)

Write-Host "🏒 Deploying NHL Stats DevOps Demo..." -ForegroundColor Green

# Check prerequisites
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error "AWS CLI not found. Please install AWS CLI first."
    exit 1
}

if (-not (Get-Command sam -ErrorAction SilentlyContinue)) {
    Write-Error "SAM CLI not found. Please install SAM CLI first."
    exit 1
}

if ([string]::IsNullOrEmpty($GitHubToken)) {
    Write-Error "GitHub token is required. Use -GitHubToken parameter."
    exit 1
}

# Deploy infrastructure
Write-Host "📦 Deploying CodePipeline infrastructure..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file infrastructure/codepipeline-stack.yaml `
    --stack-name nhl-stats-codepipeline `
    --parameter-overrides GitHubRepo=$GitHubRepo GitHubToken=$GitHubToken `
    --capabilities CAPABILITY_IAM `
    --region $Region

Write-Host "🚀 Deploying EKS cluster..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file infrastructure/eks-cluster.yaml `
    --stack-name nhl-stats-eks `
    --capabilities CAPABILITY_IAM `
    --region $Region

# Deploy NHL API Service using SAM
Write-Host "🏒 Deploying NHL API Service..." -ForegroundColor Yellow
Set-Location nhl-api-service
sam build
sam deploy --guided --stack-name nhl-api-service
Set-Location ..

Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Push code to GitHub to trigger pipelines"
Write-Host "2. Configure kubectl for EKS cluster"
Write-Host "3. Deploy stats-processing service to EKS"
Write-Host "4. Check AWS Console for pipeline status"