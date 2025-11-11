# One-time infrastructure setup - Run locally with AWS CLI
param(
    [string]$GitHubOrg = "jessetop",
    [string]$GitHubRepo = "aws-devops-nhl-demo",
    [string]$GitHubToken = "",
    [string]$GitHubBranch = "trunk",
    [switch]$UseDefaultVPC = $false,
    [string]$StackName = "nhl-stats"
)

# Function to validate GitHub token
function Test-GitHubToken {
    param(
        [string]$Token,
        [string]$Repository
    )
    
    if ([string]::IsNullOrEmpty($Token)) {
        Write-Host "❌ Error: GitHub token is required but not provided" -ForegroundColor Red
        Write-Host ""
        Write-Host "💡 If you set `$env:GITHUB_TOKEN as an environment variable, make sure it's still set:" -ForegroundColor Yellow
        Write-Host "   `$env:GITHUB_TOKEN = 'your_token_here'" -ForegroundColor White
        Write-Host "   Write-Host `$env:GITHUB_TOKEN  # Should show your token" -ForegroundColor White
        Write-Host ""
        Write-Host "Usage: .\windows-setup-infrastructure.ps1 -GitHubOrg 'myorg' -GitHubToken 'ghp_token' [-UseDefaultVPC]" -ForegroundColor White
        Write-Host "Example: .\windows-setup-infrastructure.ps1 -GitHubOrg 'jessetop' -GitHubToken `$env:GITHUB_TOKEN -UseDefaultVPC" -ForegroundColor White
        return $false
    }
    
    Write-Host "🔍 Validating GitHub token access to $Repository..." -ForegroundColor Yellow
    
    try {
        $headers = @{ Authorization = "token $Token" }
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository" -Headers $headers -ErrorAction Stop
        Write-Host "✅ GitHub token is valid and has access to $Repository" -ForegroundColor Green
        return $true
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        switch ($statusCode) {
            401 {
                Write-Host "❌ GitHub token is invalid or expired" -ForegroundColor Red
                Write-Host "💡 Generate a new token at: https://github.com/settings/tokens" -ForegroundColor Yellow
                Write-Host "   Required scopes: repo, admin:repo_hook" -ForegroundColor White
            }
            404 {
                Write-Host "❌ Repository $Repository not found or token lacks access" -ForegroundColor Red
                Write-Host "💡 Check repository name and token permissions" -ForegroundColor Yellow
            }
            default {
                Write-Host "❌ GitHub API error (HTTP $statusCode)" -ForegroundColor Red
            }
        }
        return $false
    }
}

# Validate GitHub token
if (-not (Test-GitHubToken -Token $GitHubToken -Repository "$GitHubOrg/$GitHubRepo")) {
    exit 1
}

Write-Host "🔧 Setting up infrastructure..." -ForegroundColor Green

# Install required tools
& .\utils\install-eksctl.ps1
& .\utils\install-kubectl.ps1

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

# 5. Configure EKS access for CodeBuild role
Write-Host "Configuring EKS access for CodeBuild role..." -ForegroundColor Yellow

# Get CodeBuild role ARN from CloudFormation
$CodeBuildRoleArn = aws cloudformation describe-stacks --stack-name "$StackName-codepipeline" --query 'Stacks[0].Outputs[?OutputKey==`CodeBuildRoleArn`].OutputValue' --output text 2>$null

if ([string]::IsNullOrEmpty($CodeBuildRoleArn)) {
    Write-Host "Getting CodeBuild role ARN from IAM..." -ForegroundColor Yellow
    $RoleName = aws iam list-roles --query "Roles[?contains(RoleName, '$StackName') && contains(RoleName, 'CodeBuildRole')].RoleName" --output text
    if (-not [string]::IsNullOrEmpty($RoleName)) {
        $RoleName = ($RoleName -split "`t")[0]  # Take first match
        $CodeBuildRoleArn = aws iam get-role --role-name $RoleName --query 'Role.Arn' --output text
    }
}

if (-not [string]::IsNullOrEmpty($CodeBuildRoleArn)) {
    Write-Host "CodeBuild Role ARN: $CodeBuildRoleArn" -ForegroundColor Cyan
    
    # Create access entry
    Write-Host "Creating EKS access entry..." -ForegroundColor Yellow
    aws eks create-access-entry --cluster-name "$StackName-cluster" --principal-arn $CodeBuildRoleArn --type STANDARD 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Access entry created successfully" -ForegroundColor Green
    } else {
        Write-Host "Access entry already exists or failed to create" -ForegroundColor Yellow
    }
    
    # Associate policy
    Write-Host "Associating EKS policy..." -ForegroundColor Yellow
    aws eks associate-access-policy --cluster-name "$StackName-cluster" --principal-arn $CodeBuildRoleArn --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" --access-scope type=cluster 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Policy associated successfully" -ForegroundColor Green
    } else {
        Write-Host "Policy already associated or failed to associate" -ForegroundColor Yellow
    }
    
    Write-Host "✅ EKS access configured for CodeBuild role" -ForegroundColor Green
} else {
    Write-Host "⚠️  Could not find CodeBuild role ARN - you may need to run utils\configure-eks-access.ps1 manually" -ForegroundColor Yellow
}

# Get the GitHub role ARN for secrets
$RoleArn = aws cloudformation describe-stacks `
    --stack-name $StackName-oidc-role `
    --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' `
    --output text

Write-Host "✅ Infrastructure created!" -ForegroundColor Green
Write-Host "Add this to GitHub Secrets:" -ForegroundColor Cyan
Write-Host "AWS_ROLE_ARN = $RoleArn" -ForegroundColor White