#!/bin/bash
# One-time infrastructure setup - Run locally with AWS CLI

GITHUB_ORG=${1:-"jessetop"}
GITHUB_REPO=${2:-"aws-devops-pipeline-demo"}
GITHUB_TOKEN=${3:-""}

echo "🔧 Setting up infrastructure..."

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GitHub token is required"
    echo "Usage: ./setup-infrastructure.sh <github-org> <github-repo> <github-token>"
    exit 1
fi

# Enable strict error handling
set -e

# 1. Create GitHub OIDC Provider (using CLI - CloudFormation resource not available in all regions)
echo "Creating GitHub OIDC provider..."
OIDC_EXISTS=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text)

if [ -z "$OIDC_EXISTS" ]; then
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
    echo "✅ GitHub OIDC provider created"
else
    echo "✅ GitHub OIDC provider already exists"
fi

# 2. Create GitHub OIDC Role
echo "Checking GitHub OIDC role stack..."
ROLE_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name github-oidc-role --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_EXISTS")
if [[ "$ROLE_STACK_STATUS" =~ FAILED|ROLLBACK ]]; then
    echo "Cleaning up failed stack: github-oidc-role"
    aws cloudformation delete-stack --stack-name github-oidc-role
    aws cloudformation wait stack-delete-complete --stack-name github-oidc-role
fi

echo "Creating GitHub OIDC role..."
aws cloudformation deploy \
    --template-file infrastructure/github-oidc-role.yaml \
    --stack-name github-oidc-role \
    --parameter-overrides GitHubOrg=$GITHUB_ORG GitHubRepo=$GITHUB_REPO \
    --capabilities CAPABILITY_NAMED_IAM

echo "✅ GitHub OIDC role created successfully"

# 3. Create CodePipeline infrastructure
echo "Checking CodePipeline stack..."
PIPELINE_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name nhl-stats-codepipeline --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_EXISTS")
if [[ "$PIPELINE_STACK_STATUS" =~ FAILED|ROLLBACK ]]; then
    echo "Cleaning up failed stack: nhl-stats-codepipeline"
    aws cloudformation delete-stack --stack-name nhl-stats-codepipeline
    aws cloudformation wait stack-delete-complete --stack-name nhl-stats-codepipeline
fi

echo "Creating CodePipeline infrastructure..."
aws cloudformation deploy \
    --template-file infrastructure/codepipeline-stack.yaml \
    --stack-name nhl-stats-codepipeline \
    --parameter-overrides GitHubRepo="$GITHUB_ORG/$GITHUB_REPO" GitHubToken=$GITHUB_TOKEN \
    --capabilities CAPABILITY_IAM

echo "✅ CodePipeline infrastructure created successfully"

# 4. Get latest EKS version and create cluster
echo "Checking EKS stack..."
EKS_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name nhl-stats-eks --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_EXISTS")
if [[ "$EKS_STACK_STATUS" =~ FAILED|ROLLBACK ]]; then
    echo "Cleaning up failed stack: nhl-stats-eks"
    aws cloudformation delete-stack --stack-name nhl-stats-eks
    aws cloudformation wait stack-delete-complete --stack-name nhl-stats-eks
fi

echo "Getting latest EKS version..."
LATEST_EKS_VERSION=$(aws eks describe-addon-versions --query 'addons[0].addonVersions[0].compatibilities[0].clusterVersion' --output text)
echo "Using EKS version: $LATEST_EKS_VERSION"

echo "Creating EKS cluster..."
aws cloudformation deploy \
    --template-file infrastructure/eks-cluster.yaml \
    --stack-name nhl-stats-eks \
    --parameter-overrides EksVersion=$LATEST_EKS_VERSION \
    --capabilities CAPABILITY_IAM

echo "✅ EKS cluster created successfully"

# Get the GitHub role ARN for secrets
ROLE_ARN=$(aws cloudformation describe-stacks \
    --stack-name github-oidc-role \
    --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' \
    --output text)

echo "✅ Infrastructure created!"
echo "Add this to GitHub Secrets:"
echo "AWS_ROLE_ARN = $ROLE_ARN"
