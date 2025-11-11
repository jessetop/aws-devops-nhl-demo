#!/bin/bash
# One-time infrastructure setup - Run locally with AWS CLI

# Default values
GITHUB_ORG="jessetop"
GITHUB_REPO="aws-devops-pipeline-demo"
GITHUB_TOKEN=""
GITHUB_BRANCH="main"
USE_DEFAULT_VPC="false"
STACK_NAME="nhl-stats"

# Parse named parameters
while [[ $# -gt 0 ]]; do
  case $1 in
    -GitHubOrg)
      GITHUB_ORG="$2"
      shift 2
      ;;
    -GitHubToken)
      GITHUB_TOKEN="$2"
      shift 2
      ;;
    -GitHubRepo)
      GITHUB_REPO="$2"
      shift 2
      ;;
    -GitHubBranch)
      GITHUB_BRANCH="$2"
      shift 2
      ;;
    -UseDefaultVPC)
      USE_DEFAULT_VPC="true"
      shift
      ;;
    -StackName)
      STACK_NAME="$2"
      shift 2
      ;;
    *)
      # Fallback to positional parameters for backward compatibility
      if [ -z "${GITHUB_ORG_SET}" ]; then
        GITHUB_ORG="$1"
        GITHUB_ORG_SET=true
      elif [ -z "${GITHUB_REPO_SET}" ]; then
        GITHUB_REPO="$1"
        GITHUB_REPO_SET=true
      elif [ -z "${GITHUB_TOKEN_SET}" ]; then
        GITHUB_TOKEN="$1"
        GITHUB_TOKEN_SET=true
      elif [ -z "${GITHUB_BRANCH_SET}" ]; then
        GITHUB_BRANCH="$1"
        GITHUB_BRANCH_SET=true
      elif [ "$1" = "true" ]; then
        USE_DEFAULT_VPC="true"
      fi
      shift
      ;;
  esac
done

echo "🔧 Setting up infrastructure..."

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GitHub token is required"
    echo "Usage (named parameters): ./setup-infrastructure.sh -GitHubOrg \"myorg\" -GitHubToken \"ghp_token\" [-UseDefaultVPC]"
    echo "Usage (positional): ./setup-infrastructure.sh myorg myrepo ghp_token [branch] [true]"
    echo "Example: ./setup-infrastructure.sh -GitHubOrg \"jessetop\" -GitHubToken \"$GITHUB_TOKEN\" -UseDefaultVPC"
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
ROLE_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME}-oidc-role --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_EXISTS")
if [[ "$ROLE_STACK_STATUS" =~ FAILED|ROLLBACK ]]; then
    echo "Cleaning up failed stack: ${STACK_NAME}-oidc-role"
    aws cloudformation delete-stack --stack-name ${STACK_NAME}-oidc-role
    aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME}-oidc-role
fi

echo "Creating GitHub OIDC role..."
aws cloudformation deploy \
    --template-file infrastructure/github-oidc-role.yaml \
    --stack-name ${STACK_NAME}-oidc-role \
    --parameter-overrides GitHubOrg=$GITHUB_ORG GitHubRepo=$GITHUB_REPO StackName=$STACK_NAME \
    --capabilities CAPABILITY_NAMED_IAM

echo "✅ GitHub OIDC role created successfully"

# 3. Create CodePipeline infrastructure
echo "Checking CodePipeline stack..."
PIPELINE_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME}-codepipeline --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_EXISTS")
if [[ "$PIPELINE_STACK_STATUS" =~ FAILED|ROLLBACK ]]; then
    echo "Cleaning up failed stack: ${STACK_NAME}-codepipeline"
    aws cloudformation delete-stack --stack-name ${STACK_NAME}-codepipeline
    aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME}-codepipeline
fi

echo "Creating CodePipeline infrastructure..."
aws cloudformation deploy \
    --template-file infrastructure/codepipeline-stack.yaml \
    --stack-name ${STACK_NAME}-codepipeline \
    --parameter-overrides GitHubRepo="$GITHUB_ORG/$GITHUB_REPO" GitHubToken=$GITHUB_TOKEN GitHubBranch=$GITHUB_BRANCH StackName=$STACK_NAME \
    --capabilities CAPABILITY_IAM

echo "✅ CodePipeline infrastructure created successfully"

# 4. Create EKS cluster using eksctl
echo "Checking EKS CloudFormation stacks..."
EKS_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name eksctl-${STACK_NAME}-cluster-cluster --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_EXISTS")
if [[ "$EKS_STACK_STATUS" =~ FAILED|ROLLBACK ]]; then
    echo "Cleaning up failed eksctl stack: eksctl-${STACK_NAME}-cluster-cluster"
    eksctl delete cluster --name ${STACK_NAME}-cluster --wait
fi

NODE_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name eksctl-${STACK_NAME}-cluster-nodegroup-${STACK_NAME}-eks-nodes --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_EXISTS")
if [[ "$NODE_STACK_STATUS" =~ FAILED|ROLLBACK ]]; then
    echo "Cleaning up failed nodegroup stack"
    eksctl delete cluster --name ${STACK_NAME}-cluster --wait
fi

echo "Checking if EKS cluster exists..."
CLUSTER_EXISTS=$(aws eks describe-cluster --name ${STACK_NAME}-cluster --query 'cluster.name' --output text 2>/dev/null || echo "NOT_EXISTS")

if [ "$CLUSTER_EXISTS" = "${STACK_NAME}-cluster" ]; then
    echo "✅ EKS cluster already exists"
else
    # Get latest EKS version and update config
    echo "Getting latest EKS version..."
    LATEST_EKS_VERSION=$(aws eks describe-addon-versions --addon-name vpc-cni --query 'addons[0].addonVersions[0].compatibilities[-1].clusterVersion' --output text)
    echo "Using EKS version: $LATEST_EKS_VERSION"
    
    # Choose config file based on VPC preference
    if [ "$USE_DEFAULT_VPC" = "true" ]; then
        echo "Using default VPC for faster deployment"
        CONFIG_FILE="infrastructure/eks-cluster-default-vpc.yaml"
    else
        echo "Creating new VPC with cluster"
        CONFIG_FILE="infrastructure/eks-cluster.yaml"
    fi
    
    # Update cluster config with latest version and stack name
    sed -i "s/^# kubernetesVersion:.*/kubernetesVersion: \"$LATEST_EKS_VERSION\"/" $CONFIG_FILE
    sed -i "s/name: nhl-stats-cluster/name: ${STACK_NAME}-cluster/" $CONFIG_FILE
    sed -i "s/name: nhl-stats-eks-nodes/name: ${STACK_NAME}-eks-nodes/" $CONFIG_FILE
    
    echo "Creating EKS cluster with eksctl..."
    eksctl create cluster --config-file $CONFIG_FILE --wait
    echo "✅ EKS cluster created successfully"
fi

# Get the GitHub role ARN for secrets
ROLE_ARN=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME}-oidc-role \
    --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' \
    --output text)

echo "✅ Infrastructure created!"
echo "Add this to GitHub Secrets:"
echo "AWS_ROLE_ARN = $ROLE_ARN"
