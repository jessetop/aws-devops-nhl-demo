# Configure EKS access for CodeBuild role
# Usage: .\configure-eks-access.ps1 -StackName "nhl-stats"

param(
    [string]$StackName = "nhl-stats"
)

$ClusterName = "$StackName-cluster"

Write-Host "Configuring EKS access for CodeBuild role..." -ForegroundColor Green

# Get CodeBuild role ARN from CloudFormation
try {
    $CodeBuildRoleArn = aws cloudformation describe-stacks --stack-name "$StackName-codepipeline" --query 'Stacks[0].Outputs[?OutputKey==`CodeBuildRoleArn`].OutputValue' --output text 2>$null
} catch {
    $CodeBuildRoleArn = $null
}

if ([string]::IsNullOrEmpty($CodeBuildRoleArn)) {
    Write-Host "Could not find CodeBuild role ARN from CloudFormation. Getting from IAM..." -ForegroundColor Yellow
    try {
        $RoleName = aws iam list-roles --query "Roles[?contains(RoleName, '$StackName') && contains(RoleName, 'CodeBuildRole')].RoleName" --output text
        if ($RoleName) {
            $CodeBuildRoleArn = aws iam get-role --role-name $RoleName --query 'Role.Arn' --output text
        }
    } catch {
        Write-Host "Error: Could not find CodeBuild role ARN" -ForegroundColor Red
        exit 1
    }
}

Write-Host "CodeBuild Role ARN: $CodeBuildRoleArn" -ForegroundColor Cyan
Write-Host "EKS Cluster: $ClusterName" -ForegroundColor Cyan

# Create access entry
Write-Host "Creating EKS access entry..." -ForegroundColor Yellow
try {
    aws eks create-access-entry --cluster-name $ClusterName --principal-arn $CodeBuildRoleArn --type STANDARD
    Write-Host "Access entry created successfully" -ForegroundColor Green
} catch {
    Write-Host "Access entry already exists or failed to create" -ForegroundColor Yellow
}

# Associate policy
Write-Host "Associating EKS policy..." -ForegroundColor Yellow
try {
    aws eks associate-access-policy --cluster-name $ClusterName --principal-arn $CodeBuildRoleArn --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" --access-scope type=cluster
    Write-Host "Policy associated successfully" -ForegroundColor Green
} catch {
    Write-Host "Policy already associated or failed to associate" -ForegroundColor Yellow
}

Write-Host "EKS access configuration completed!" -ForegroundColor Green