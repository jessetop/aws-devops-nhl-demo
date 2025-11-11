# One-time infrastructure setup - Run locally with AWS CLI
param(
    [string]$GitHubOrg = "your-username",
    [string]$GitHubRepo = "aws-devops-pipeline-demo",
    [string]$GitHubToken = ""
)

Write-Host "🔧 Setting up infrastructure..." -ForegroundColor Green

# 1. Create GitHub OIDC Provider (using CLI - CloudFormation resource not available in all regions)
Write-Host "Creating GitHub OIDC provider..." -ForegroundColor Yellow
$OidcExists = aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text

if ([string]::IsNullOrEmpty($OidcExists)) {
    aws iam create-open-id-connect-provider `
        --url https://token.actions.githubusercontent.com `
        --client-id-list sts.amazonaws.com `
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ GitHub OIDC provider creation failed. Aborting."
        exit 1
    }
    Write-Host "✅ GitHub OIDC provider created" -ForegroundColor Green
} else {
    Write-Host "✅ GitHub OIDC provider already exists" -ForegroundColor Green
}

# 2. Create GitHub OIDC Role
Write-Host "Creating GitHub OIDC role..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file infrastructure/github-oidc-role.yaml `
    --stack-name github-oidc-role `
    --parameter-overrides GitHubOrg=$GitHubOrg GitHubRepo=$GitHubRepo `
    --capabilities CAPABILITY_NAMED_IAM

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ GitHub OIDC role deployment failed. Aborting."
    exit 1
}
Write-Host "✅ GitHub OIDC role created successfully" -ForegroundColor Green

# 2. Create CodePipeline infrastructure
Write-Host "Creating CodePipeline infrastructure..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file infrastructure/codepipeline-stack.yaml `
    --stack-name nhl-stats-codepipeline `
    --parameter-overrides GitHubRepo="$GitHubOrg/$GitHubRepo" GitHubToken=$GitHubToken `
    --capabilities CAPABILITY_IAM

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ CodePipeline infrastructure deployment failed. Aborting."
    exit 1
}
Write-Host "✅ CodePipeline infrastructure created successfully" -ForegroundColor Green

# 3. Get latest EKS version and create cluster
Write-Host "Getting latest EKS version..." -ForegroundColor Yellow
$LatestEksVersion = aws eks describe-addon-versions --query 'addons[0].addonVersions[0].compatibilities[0].clusterVersion' --output text
Write-Host "Using EKS version: $LatestEksVersion" -ForegroundColor Cyan

Write-Host "Creating EKS cluster..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file infrastructure/eks-cluster.yaml `
    --stack-name nhl-stats-eks `
    --parameter-overrides EksVersion=$LatestEksVersion `
    --capabilities CAPABILITY_IAM

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ EKS cluster deployment failed. Aborting."
    exit 1
}
Write-Host "✅ EKS cluster created successfully" -ForegroundColor Green

# Get the GitHub role ARN for secrets
$RoleArn = aws cloudformation describe-stacks `
    --stack-name github-oidc-role `
    --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' `
    --output text

Write-Host "✅ Infrastructure created!" -ForegroundColor Green
Write-Host "Add this to GitHub Secrets:" -ForegroundColor Cyan
Write-Host "AWS_ROLE_ARN = $RoleArn" -ForegroundColor White