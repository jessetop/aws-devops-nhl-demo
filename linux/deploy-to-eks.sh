#!/bin/bash
# Deploy stats processing service to EKS - Run after infrastructure setup

REGION=${1:-"us-east-1"}
CLUSTER_NAME=${2:-"nhl-stats-cluster"}

echo "🚀 Deploying to EKS..."

# Enable strict error handling
set -e

# Update kubeconfig (eksctl creates this automatically, but ensure it's current)
echo "Updating kubeconfig..."
eksctl utils write-kubeconfig --cluster $CLUSTER_NAME --region $REGION

if [ $? -ne 0 ]; then
    echo "Trying alternative kubeconfig update..."
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
fi

# Get ECR repository URI
echo "Getting ECR repository URI..."
ECR_URI=$(aws cloudformation describe-stacks \
    --stack-name nhl-stats-codepipeline \
    --query 'Stacks[0].Outputs[?OutputKey==`StatsProcessingECR`].OutputValue' \
    --output text)

# Update deployment with correct ECR URI
echo "Updating deployment manifest..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" stats-processing-service/k8s-deployment.yaml
sed -i "s/REGION/$REGION/g" stats-processing-service/k8s-deployment.yaml

# Deploy to EKS
echo "Deploying to Kubernetes..."
kubectl apply -f stats-processing-service/k8s-deployment.yaml

echo "✅ EKS deployment complete!"
echo "Check status with: kubectl get pods"