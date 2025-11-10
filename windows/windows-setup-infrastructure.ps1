# One-time infrastructure setup - Run locally with AWS CLI
param(
    [string]$GitHubOrg = "your-username",
    [string]$GitHubRepo = "aws-devops-pipeline-demo",
    [string]$GitHubToken = ""
)

Write-Host "🔧 Setting up infrastructure..." -ForegroundColor Green

# 1. Create GitHub OIDC Role (enables secure GitHub Actions)
Write-Host "Creating GitHub OIDC role..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file infrastructure/github-oidc-role.yaml `
    --stack-name github-oidc-role `
    --parameter-overrides GitHubOrg=$GitHubOrg GitHubRepo=$GitHubRepo `
    --capabilities CAPABILITY_NAMED_IAM

# 2. Create CodePipeline infrastructure
Write-Host "Creating CodePipeline infrastructure..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file infrastructure/codepipeline-stack.yaml `
    --stack-name nhl-stats-codepipeline `
    --parameter-overrides GitHubRepo="$GitHubOrg/$GitHubRepo" GitHubToken=$GitHubToken `
    --capabilities CAPABILITY_IAM

# 3. Create EKS cluster
Write-Host "Creating EKS cluster..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file infrastructure/eks-cluster.yaml `
    --stack-name nhl-stats-eks `
    --capabilities CAPABILITY_IAM

# Get the GitHub role ARN for secrets
$RoleArn = aws cloudformation describe-stacks `
    --stack-name github-oidc-role `
    --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' `
    --output text

Write-Host "✅ Infrastructure created!" -ForegroundColor Green
Write-Host "Add this to GitHub Secrets:" -ForegroundColor Cyan
Write-Host "AWS_ROLE_ARN = $RoleArn" -ForegroundColor White