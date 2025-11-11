#!/bin/bash
# One-time infrastructure setup - Run locally with AWS CLI

# Default values
GITHUB_ORG="jessetop"
GITHUB_REPO="aws-devops-nhl-demo"
GITHUB_TOKEN=""
GITHUB_BRANCH="main"
USE_DEFAULT_VPC="false"
STACK_NAME="nhl-stats"
REGION="us-east-1"

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
    -Region)
      REGION="$2"
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

# Install required tools
source utils/install-eksctl.sh
source utils/install-kubectl.sh

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
    eksctl delete cluster --name ${STACK_NAME}-cluster
fi

NODE_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name eksctl-${STACK_NAME}-cluster-nodegroup-${STACK_NAME}-eks-nodes --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_EXISTS")
if [[ "$NODE_STACK_STATUS" =~ FAILED|ROLLBACK ]]; then
    echo "Cleaning up failed nodegroup stack"
    eksctl delete cluster --name ${STACK_NAME}-cluster
fi

echo "Checking if EKS cluster exists..."
CLUSTER_EXISTS=$(aws eks describe-cluster --name ${STACK_NAME}-cluster --query 'cluster.name' --output text 2>/dev/null || echo "NOT_EXISTS")

if [ "$CLUSTER_EXISTS" = "${STACK_NAME}-cluster" ]; then
    echo "✅ EKS cluster already exists"
else
    # Get latest EKS version and update config
    echo "Getting latest EKS version..."
    LATEST_EKS_VERSION=$(aws eks describe-addon-versions --addon-name vpc-cni --query 'addons[0].addonVersions[0].compatibilities[0].clusterVersion' --output text)
    echo "Using EKS version: $LATEST_EKS_VERSION"
    
    # Create cluster with or without default VPC
    if [ "$USE_DEFAULT_VPC" = "true" ]; then
        echo "Using default VPC for faster deployment"
        eksctl create cluster \
            --name ${STACK_NAME}-cluster \
            --version $LATEST_EKS_VERSION \
            --region $REGION \
            --nodegroup-name ${STACK_NAME}-eks-nodes \
            --node-type t3.medium \
            --nodes 2 \
            --nodes-min 1 \
            --nodes-max 3 \
            --vpc-from-kops-cluster false
    else
        echo "Creating new VPC with cluster"
        CONFIG_FILE="infrastructure/eks-cluster.yaml"
        
        # Create temp config file to avoid permission issues
        TEMP_CONFIG="/tmp/eks-cluster-${STACK_NAME}.yaml"
        cp $CONFIG_FILE $TEMP_CONFIG
        
        # Update cluster config with latest version, stack name, and region
        sed "s/# version: \".*\"/version: \"$LATEST_EKS_VERSION\"/" $TEMP_CONFIG > $TEMP_CONFIG.tmp && mv $TEMP_CONFIG.tmp $TEMP_CONFIG
        sed "s/name: nhl-stats-cluster/name: ${STACK_NAME}-cluster/" $TEMP_CONFIG > $TEMP_CONFIG.tmp && mv $TEMP_CONFIG.tmp $TEMP_CONFIG
        sed "s/name: nhl-stats-eks-nodes/name: ${STACK_NAME}-eks-nodes/" $TEMP_CONFIG > $TEMP_CONFIG.tmp && mv $TEMP_CONFIG.tmp $TEMP_CONFIG
        sed "s/region: REGION_PLACEHOLDER/region: $REGION/" $TEMP_CONFIG > $TEMP_CONFIG.tmp && mv $TEMP_CONFIG.tmp $TEMP_CONFIG
        
        eksctl create cluster --config-file $TEMP_CONFIG
    fi
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
