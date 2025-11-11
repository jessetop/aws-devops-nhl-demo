#!/bin/bash
# Check status of all pipelines - GitHub Actions and CodePipeline

GITHUB_ORG=${1:-"jessetop"}
GITHUB_REPO=${2:-"aws-devops-nhl-demo"}
STACK_NAME=${3:-"eks-nhl-test"}

echo "🔍 Checking Pipeline Status..."
echo "================================"

# GitHub Actions Status
echo "📋 GitHub Actions (NHL API Service):"
if [ -n "$GITHUB_TOKEN" ]; then
    WORKFLOW_RUNS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/actions/runs?per_page=5")
    
    echo "$WORKFLOW_RUNS" | jq -r '.workflow_runs[] | select(.name == "Deploy NHL API Service") | 
        "  Status: \(.status) | Conclusion: \(.conclusion // "running") | Branch: \(.head_branch) | \(.created_at)"' | head -3
else
    echo "  ⚠️  GITHUB_TOKEN not set - cannot check GitHub Actions status"
fi

echo ""

# CodePipeline Status
echo "🔧 AWS CodePipeline Status:"

# Stats Processing Pipeline
echo "  Stats Processing Pipeline:"
STATS_STATUS=$(aws codepipeline get-pipeline-state --name ${STACK_NAME}-stats-processing-pipeline --query 'stageStates[*].{Stage:stageName,Status:latestExecution.status}' --output table 2>/dev/null || echo "Pipeline not found")
echo "$STATS_STATUS" | sed 's/^/    /'

echo ""

# Web Frontend Pipeline  
echo "  Web Frontend Pipeline:"
WEB_STATUS=$(aws codepipeline get-pipeline-state --name ${STACK_NAME}-web-frontend-pipeline --query 'stageStates[*].{Stage:stageName,Status:latestExecution.status}' --output table 2>/dev/null || echo "Pipeline not found")
echo "$WEB_STATUS" | sed 's/^/    /'

echo ""
echo "🏒 Quick Commands:"
echo "  GitHub Actions: https://github.com/$GITHUB_ORG/$GITHUB_REPO/actions"
echo "  CodePipeline: https://console.aws.amazon.com/codesuite/codepipeline/pipelines"