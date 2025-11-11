#!/bin/bash

# Configure EKS access for CodeBuild role
# Usage: ./configure-eks-access.sh <stack-name>

STACK_NAME=${1:-nhl-stats}
CLUSTER_NAME="${STACK_NAME}-cluster"

echo "Configuring EKS access for CodeBuild role..."

# Get CodeBuild role ARN from CloudFormation
CODEBUILD_ROLE_ARN=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}-codepipeline" \
    --query 'Stacks[0].Outputs[?OutputKey==`CodeBuildRoleArn`].OutputValue' \
    --output text 2>/dev/null)

if [ -z "$CODEBUILD_ROLE_ARN" ]; then
    echo "Could not find CodeBuild role ARN. Getting from IAM..."
    CODEBUILD_ROLE_ARN=$(aws iam get-role --role-name "${STACK_NAME}-codepipeline-CodeBuildRole-*" --query 'Role.Arn' --output text 2>/dev/null)
fi

if [ -z "$CODEBUILD_ROLE_ARN" ]; then
    echo "Error: Could not find CodeBuild role ARN"
    exit 1
fi

echo "CodeBuild Role ARN: $CODEBUILD_ROLE_ARN"
echo "EKS Cluster: $CLUSTER_NAME"

# Create access entry
echo "Creating EKS access entry..."
aws eks create-access-entry \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$CODEBUILD_ROLE_ARN" \
    --type STANDARD || echo "Access entry already exists"

# Associate policy
echo "Associating EKS policy..."
aws eks associate-access-policy \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$CODEBUILD_ROLE_ARN" \
    --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" \
    --access-scope type=cluster || echo "Policy already associated"

echo "EKS access configuration completed!"