# One-time infrastructure setup - Run locally with AWS CLI
param(
    [string]$GitHubOrg = "your-username",
    [string]$GitHubRepo = "aws-devops-pipeline-demo",
    [string]$GitHubToken = "",
    [string]$GitHubBranch = "main",
    [switch]$UseDefaultVPC = $false,
    [string]$StackName = "nhl-stats"
)

Write-Host "🔧 Setting up infrastructure..." -ForegroundColor Green

# Check and install eksctl if needed
Write-Host "Checking eksctl installation..." -ForegroundColor Yellow
try {
    $eksctlVersion = eksctl version --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty GitTag
    Write-Host "✅ eksctl already installed: $eksctlVersion" -ForegroundColor Green
} catch {
    Write-Host "Installing eksctl..." -ForegroundColor Yellow
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install eksctl -y
    } else {
        Write-Host "Downloading eksctl manually..." -ForegroundColor Yellow
        $eksctlUrl = "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Windows_amd64.zip"
        $tempPath = "$env:TEMP\eksctl.zip"
        Invoke-WebRequest -Uri $eksctlUrl -OutFile $tempPath
        Expand-Archive -Path $tempPath -DestinationPath "$env:TEMP\eksctl" -Force
        $programFiles = ${env:ProgramFiles}
        if (-not (Test-Path "$programFiles\eksctl")) {
            New-Item -ItemType Directory -Path "$programFiles\eksctl" -Force
        }
        Copy-Item "$env:TEMP\eksctl\eksctl.exe" "$programFiles\eksctl\eksctl.exe" -Force
        $env:PATH += ";$programFiles\eksctl"
        [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "Machine")
    }
    Write-Host "✅ eksctl installed successfully" -ForegroundColor Green
}

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
Write-Host "Checking GitHub OIDC role stack..." -ForegroundColor Yellow
$RoleStackStatus = aws cloudformation describe-stacks --stack-name $StackName-oidc-role --query 'Stacks[0].StackStatus' --output text 2>$null
if ($RoleStackStatus -match "FAILED|ROLLBACK") {
    Write-Host "Cleaning up failed stack: $StackName-oidc-role" -ForegroundColor Red
    aws cloudformation delete-stack --stack-name $StackName-oidc-role
    aws cloudformation wait stack-delete-complete --stack-name $StackName-oidc-role
}

Write-Host "Creating GitHub OIDC role..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file infrastructure/github-oidc-role.yaml `
    --stack-name $StackName-oidc-role `
    --parameter-overrides GitHubOrg=$GitHubOrg GitHubRepo=$GitHubRepo StackName=$StackName `
    --capabilities CAPABILITY_NAMED_IAM

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ GitHub OIDC role deployment failed. Aborting."
    exit 1
}
Write-Host "✅ GitHub OIDC role created successfully" -ForegroundColor Green

# 3. Create CodePipeline infrastructure
Write-Host "Checking CodePipeline stack..." -ForegroundColor Yellow
$PipelineStackStatus = aws cloudformation describe-stacks --stack-name $StackName-codepipeline --query 'Stacks[0].StackStatus' --output text 2>$null
if ($PipelineStackStatus -match "FAILED|ROLLBACK") {
    Write-Host "Cleaning up failed stack: $StackName-codepipeline" -ForegroundColor Red
    aws cloudformation delete-stack --stack-name $StackName-codepipeline
    aws cloudformation wait stack-delete-complete --stack-name $StackName-codepipeline
}

Write-Host "Creating CodePipeline infrastructure..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file infrastructure/codepipeline-stack.yaml `
    --stack-name $StackName-codepipeline `
    --parameter-overrides GitHubRepo="$GitHubOrg/$GitHubRepo" GitHubToken=$GitHubToken GitHubBranch=$GitHubBranch StackName=$StackName `
    --capabilities CAPABILITY_IAM

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ CodePipeline infrastructure deployment failed. Aborting."
    exit 1
}
Write-Host "✅ CodePipeline infrastructure created successfully" -ForegroundColor Green

# 4. Create EKS cluster using eksctl
Write-Host "Checking EKS CloudFormation stacks..." -ForegroundColor Yellow
$EksStackStatus = aws cloudformation describe-stacks --stack-name eksctl-$StackName-cluster-cluster --query 'Stacks[0].StackStatus' --output text 2>$null
if ($EksStackStatus -match "FAILED|ROLLBACK") {
    Write-Host "Cleaning up failed eksctl stack: eksctl-$StackName-cluster-cluster" -ForegroundColor Red
    eksctl delete cluster --name $StackName-cluster
}

$NodeStackStatus = aws cloudformation describe-stacks --stack-name eksctl-$StackName-cluster-nodegroup-$StackName-eks-nodes --query 'Stacks[0].StackStatus' --output text 2>$null
if ($NodeStackStatus -match "FAILED|ROLLBACK") {
    Write-Host "Cleaning up failed nodegroup stack" -ForegroundColor Red
    eksctl delete cluster --name $StackName-cluster
}

Write-Host "Checking if EKS cluster exists..." -ForegroundColor Yellow
$ClusterExists = aws eks describe-cluster --name $StackName-cluster --query 'cluster.name' --output text 2>$null

if ($ClusterExists -eq "$StackName-cluster") {
    Write-Host "✅ EKS cluster already exists" -ForegroundColor Green
} else {
    # Get latest EKS version and update config
    Write-Host "Getting latest EKS version..." -ForegroundColor Yellow
    $LatestEksVersion = aws eks describe-addon-versions --addon-name vpc-cni --query 'addons[0].addonVersions[0].compatibilities[0].clusterVersion' --output text
    Write-Host "Using EKS version: $LatestEksVersion" -ForegroundColor Cyan
    
    # Choose config file based on VPC preference
    if ($UseDefaultVPC) {
        Write-Host "Using default VPC for faster deployment" -ForegroundColor Cyan
        $ConfigFile = "infrastructure/eks-cluster-default-vpc.yaml"
    } else {
        Write-Host "Creating new VPC with cluster" -ForegroundColor Cyan
        $ConfigFile = "infrastructure/eks-cluster.yaml"
    }
    
    # Create temp config file to avoid permission issues
    $TempConfig = "$env:TEMP\eks-cluster-$StackName.yaml"
    Copy-Item $ConfigFile $TempConfig
    
    # Update cluster config with latest version and stack name
    (Get-Content $TempConfig) -replace 'version: ".*"', "version: `"$LatestEksVersion`"" | Set-Content $TempConfig
    (Get-Content $TempConfig) -replace 'name: nhl-stats-cluster', "name: $StackName-cluster" | Set-Content $TempConfig
    (Get-Content $TempConfig) -replace 'name: nhl-stats-eks-nodes', "name: $StackName-eks-nodes" | Set-Content $TempConfig
    
    Write-Host "Creating EKS cluster with eksctl..." -ForegroundColor Yellow
    eksctl create cluster --config-file $TempConfig
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ EKS cluster creation failed. Aborting."
        exit 1
    }
    Write-Host "✅ EKS cluster created successfully" -ForegroundColor Green
}

# Get the GitHub role ARN for secrets
$RoleArn = aws cloudformation describe-stacks `
    --stack-name $StackName-oidc-role `
    --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' `
    --output text

Write-Host "✅ Infrastructure created!" -ForegroundColor Green
Write-Host "Add this to GitHub Secrets:" -ForegroundColor Cyan
Write-Host "AWS_ROLE_ARN = $RoleArn" -ForegroundColor White