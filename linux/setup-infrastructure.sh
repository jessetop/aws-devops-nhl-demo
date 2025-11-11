#!/bin/bash
# One-time infrastructure setup - Run locally with AWS CLI

# Default values
GITHUB_ORG="jessetop"
GITHUB_REPO="aws-devops-nhl-demo"
GITHUB_TOKEN=""
GITHUB_BRANCH="trunk"
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
      if [[ "$2" == "true" || "$2" == "false" ]]; then
        USE_DEFAULT_VPC="$2"
        shift 2
      else
        USE_DEFAULT_VPC="true"
        shift
      fi
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
echo "Using GitHub token: ${GITHUB_TOKEN:0:8}..." # Show first 8 chars for verification

# Function to validate GitHub token
validate_github_token() {
    local token="$1"
    local repo="$2"
    
    if [ -z "$token" ]; then
        echo "❌ Error: GitHub token is required but not provided"
        echo ""
        echo "💡 If you set GITHUB_TOKEN as an environment variable, make sure it's still set:"
        echo "   export GITHUB_TOKEN=\"your_token_here\""
        echo "   echo \$GITHUB_TOKEN  # Should show your token"
        echo ""
        echo "Usage (named parameters): ./setup-infrastructure.sh -GitHubOrg \"myorg\" -GitHubToken \"ghp_token\" [-UseDefaultVPC]"
        echo "Usage (positional): ./setup-infrastructure.sh myorg myrepo ghp_token [branch] [true]"
        echo "Example: ./setup-infrastructure.sh -GitHubOrg \"jessetop\" -GitHubToken \"$GITHUB_TOKEN\" -UseDefaultVPC"
        return 1
    fi
    
    echo "🔍 Validating GitHub token access to $repo..."
    local response=$(curl -s -H "Authorization: token $token" "https://api.github.com/repos/$repo")
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $token" "https://api.github.com/repos/$repo")
    
    if [ "$http_code" = "200" ]; then
        echo "✅ GitHub token is valid and has access to $repo"
        return 0
    elif [ "$http_code" = "401" ]; then
        echo "❌ GitHub token is invalid or expired"
        echo "💡 Generate a new token at: https://github.com/settings/tokens"
        echo "   Required scopes: repo, admin:repo_hook"
        return 1
    elif [ "$http_code" = "404" ]; then
        echo "❌ Repository $repo not found or token lacks access"
        echo "💡 Check repository name and token permissions"
        return 1
    else
        echo "❌ GitHub API error (HTTP $http_code)"
        return 1
    fi
}

# Validate GitHub token
if ! validate_github_token "$GITHUB_TOKEN" "$GITHUB_ORG/$GITHUB_REPO"; then
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
    echo "Waiting for stack deletion (this may take a few minutes)..."
    if ! aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME}-oidc-role; then
        echo "⚠️  Stack deletion failed or timed out. You may need to manually delete resources."
        echo "🔍 Check the stack events: aws cloudformation describe-stack-events --stack-name ${STACK_NAME}-oidc-role"
        echo "💡 Try deleting the stack manually in the AWS Console if needed."
    fi
fi

echo "Creating GitHub OIDC role..."
if aws cloudformation deploy \
    --template-file infrastructure/github-oidc-role.yaml \
    --stack-name ${STACK_NAME}-oidc-role \
    --parameter-overrides GitHubOrg=$GITHUB_ORG GitHubRepo=$GITHUB_REPO StackName=$STACK_NAME \
    --capabilities CAPABILITY_NAMED_IAM; then
    echo "✅ GitHub OIDC role created successfully"
else
    echo "❌ FAILED to create GitHub OIDC role!"
    echo "🔍 Run this command to see the error details:"
    echo "aws cloudformation describe-stack-events --stack-name ${STACK_NAME}-oidc-role"
    exit 1
fi

# 3. Check if S3 artifacts bucket already exists
BUCKET_NAME="${STACK_NAME}-artifacts-${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
echo "Checking if S3 bucket exists: $BUCKET_NAME"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "⚠️  S3 bucket $BUCKET_NAME already exists - this may cause deployment issues"
    echo "💡 Consider using a different StackName or manually delete the bucket if it's safe to do so"
fi

# 3. Create CodePipeline infrastructure
echo "Checking CodePipeline stack..."
PIPELINE_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME}-codepipeline --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_EXISTS")
if [[ "$PIPELINE_STACK_STATUS" =~ FAILED|ROLLBACK ]]; then
    echo "Cleaning up failed stack: ${STACK_NAME}-codepipeline"
    aws cloudformation delete-stack --stack-name ${STACK_NAME}-codepipeline
    echo "Waiting for stack deletion (this may take a few minutes)..."
    if ! aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME}-codepipeline; then
        echo "⚠️  Stack deletion failed or timed out. You may need to manually delete resources."
        echo "🔍 Check the stack events: aws cloudformation describe-stack-events --stack-name ${STACK_NAME}-codepipeline"
        echo "💡 Try deleting the stack manually in the AWS Console if needed."
    fi
fi

echo "Creating CodePipeline infrastructure..."
if aws cloudformation deploy \
    --template-file infrastructure/codepipeline-stack.yaml \
    --stack-name ${STACK_NAME}-codepipeline \
    --parameter-overrides GitHubRepo="$GITHUB_ORG/$GITHUB_REPO" GitHubToken=$GITHUB_TOKEN GitHubBranch=$GITHUB_BRANCH StackName=$STACK_NAME \
    --capabilities CAPABILITY_IAM; then
    echo "✅ CodePipeline infrastructure created successfully"
else
    echo "❌ FAILED to create CodePipeline infrastructure!"
    echo "🔍 Run this command to see the error details:"
    echo "aws cloudformation describe-stack-events --stack-name ${STACK_NAME}-codepipeline"
    exit 1
fi

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

# 5. Configure EKS access for CodeBuild role
echo "Configuring EKS access for CodeBuild role..."

# Get CodeBuild role ARN from CloudFormation
CODEBUILD_ROLE_ARN=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}-codepipeline" \
    --query 'Stacks[0].Outputs[?OutputKey==`CodeBuildRoleArn`].OutputValue' \
    --output text 2>/dev/null)

if [ -z "$CODEBUILD_ROLE_ARN" ]; then
    echo "Getting CodeBuild role ARN from IAM..."
    ROLE_NAME=$(aws iam list-roles --query "Roles[?contains(RoleName, '${STACK_NAME}') && contains(RoleName, 'CodeBuildRole')].RoleName" --output text | head -1)
    if [ -n "$ROLE_NAME" ]; then
        CODEBUILD_ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    fi
fi

if [ -n "$CODEBUILD_ROLE_ARN" ]; then
    echo "CodeBuild Role ARN: $CODEBUILD_ROLE_ARN"
    
    # Create access entry
    echo "Creating EKS access entry..."
    aws eks create-access-entry \
        --cluster-name "${STACK_NAME}-cluster" \
        --principal-arn "$CODEBUILD_ROLE_ARN" \
        --type STANDARD || echo "Access entry already exists"
    
    # Associate policy
    echo "Associating EKS policy..."
    aws eks associate-access-policy \
        --cluster-name "${STACK_NAME}-cluster" \
        --principal-arn "$CODEBUILD_ROLE_ARN" \
        --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" \
        --access-scope type=cluster || echo "Policy already associated"
    
    echo "✅ EKS access configured for CodeBuild role"
else
    echo "⚠️  Could not find CodeBuild role ARN - you may need to run utils/configure-eks-access.sh manually"
fi

# Get the GitHub role ARN for secrets
ROLE_ARN=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME}-oidc-role \
    --query 'Stacks[0].Outputs[?OutputKey==`RoleArn`].OutputValue' \
    --output text)

echo "✅ Infrastructure created!"
echo "Add this to GitHub Secrets:"
echo "AWS_ROLE_ARN = $ROLE_ARN"
