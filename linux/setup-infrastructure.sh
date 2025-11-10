#!/bin/bash
# One-time infrastructure setup - Run locally with AWS CLI

GITHUB_ORG=${1:-"your-username"}
GITHUB_REPO=${2:-"aws-devops-pipeline-demo"}
GITHUB_TOKEN=${3:-""}

echo "🔧 Setting up infrastructure..."

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GitHub token is required"
    echo "Usage: ./setup-infrastructure.sh <github-org> <github-repo> <github-token>"
    exit 1
fi

# 1. Create GitHub OIDC Role (enables secure GitHub Actions)
echo "Creating GitHub OIDC role..."
aws cloudformation deploy \
    --template-file infrastructure/github-oidc-role.yaml \
    --stack-name github-oidc-role \
    --parameter-overrides GitHubOrg=$GITHUB_ORG GitHubRepo=$GITHUB_REPO \
    --capabilities CAPABILITY_NAMED_IAM

# 2. Create CodePipeline infrastructure
echo "Creating CodePipeline infrastructure..."
aws cloudformation deploy \
    --template-file infrastructure/codepipeline-stack.yaml \
    --stack-name nhl-stats-codepipeline \
    --parameter-overrides GitHubRepo="$GITHUB_ORG/$GITHUB_REPO" GitHubToken=$GITHUB_TOKEN \
    --capabilities CAPABILITY_IAM

# 3. Create EKS cluster
echo "Creating EKS cluster..."
aws cloudformation deploy \
    --template-file infrastructure/eks-cluster.yaml \
    --stack-name nhl-stats-eks \
    --capabilities CAPABILITY_IAM

# Get the GitHub role ARN for secrets
ROLE_ARN=$(aws cloudformation describe-stacks \
    --stack-name github-oidc-role \
    --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' \
    --output text)

echo "✅ Infrastructure created!"
echo "Add this to GitHub Secrets:"
echo "AWS_ROLE_ARN = $ROLE_ARN"