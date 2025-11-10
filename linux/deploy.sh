#!/bin/bash
# NHL Stats DevOps Demo Deployment Script

GITHUB_REPO=${1:-"your-username/aws-devops-pipeline-demo"}
GITHUB_TOKEN=${2:-""}
REGION=${3:-"us-east-1"}

echo "🏒 Deploying NHL Stats DevOps Demo..."

# Check prerequisites
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

if ! command -v sam &> /dev/null; then
    echo "Error: SAM CLI not found. Please install SAM CLI first."
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GitHub token is required"
    echo "Usage: ./deploy.sh <github-repo> <github-token> [region]"
    exit 1
fi

# Deploy infrastructure
echo "📦 Deploying CodePipeline infrastructure..."
aws cloudformation deploy \
    --template-file infrastructure/codepipeline-stack.yaml \
    --stack-name nhl-stats-codepipeline \
    --parameter-overrides GitHubRepo=$GITHUB_REPO GitHubToken=$GITHUB_TOKEN \
    --capabilities CAPABILITY_IAM \
    --region $REGION

echo "🚀 Deploying EKS cluster..."
aws cloudformation deploy \
    --template-file infrastructure/eks-cluster.yaml \
    --stack-name nhl-stats-eks \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Deploy NHL API Service using SAM
echo "🏒 Deploying NHL API Service..."
cd nhl-api-service
sam build
sam deploy --guided --stack-name nhl-api-service
cd ..

echo "✅ Deployment complete!"
echo "Next steps:"
echo "1. Push code to GitHub to trigger pipelines"
echo "2. Configure kubectl for EKS cluster"
echo "3. Deploy stats-processing service to EKS"
echo "4. Check AWS Console for pipeline status"