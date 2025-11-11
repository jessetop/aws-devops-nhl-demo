# Check status of all pipelines - GitHub Actions and CodePipeline
param(
    [string]$GitHubOrg = "jessetop",
    [string]$GitHubRepo = "aws-devops-nhl-demo", 
    [string]$StackName = "eks-nhl-test"
)

Write-Host "🔍 Checking Pipeline Status..." -ForegroundColor Green
Write-Host "================================"

# GitHub Actions Status
Write-Host "📋 GitHub Actions (NHL API Service):" -ForegroundColor Yellow
if ($env:GITHUB_TOKEN) {
    try {
        $headers = @{ Authorization = "token $env:GITHUB_TOKEN" }
        $workflowRuns = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubOrg/$GitHubRepo/actions/runs?per_page=5" -Headers $headers
        
        $workflowRuns.workflow_runs | Where-Object { $_.name -eq "Deploy NHL API Service" } | Select-Object -First 3 | ForEach-Object {
            $conclusion = if ($_.conclusion) { $_.conclusion } else { "running" }
            Write-Host "  Status: $($_.status) | Conclusion: $conclusion | Branch: $($_.head_branch) | $($_.created_at)" -ForegroundColor White
        }
    }
    catch {
        Write-Host "  ⚠️  Error checking GitHub Actions: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "  ⚠️  GITHUB_TOKEN not set - cannot check GitHub Actions status" -ForegroundColor Red
}

Write-Host ""

# CodePipeline Status
Write-Host "🔧 AWS CodePipeline Status:" -ForegroundColor Yellow

# Stats Processing Pipeline
Write-Host "  Stats Processing Pipeline:" -ForegroundColor Cyan
try {
    $statsStatus = aws codepipeline get-pipeline-state --name "$StackName-stats-processing-pipeline" --query 'stageStates[*].{Stage:stageName,Status:latestExecution.status}' --output table 2>$null
    if ($statsStatus) {
        $statsStatus -split "`n" | ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Host "    Pipeline not found" -ForegroundColor Red
    }
}
catch {
    Write-Host "    Error checking pipeline status" -ForegroundColor Red
}

Write-Host ""

# Web Frontend Pipeline
Write-Host "  Web Frontend Pipeline:" -ForegroundColor Cyan
try {
    $webStatus = aws codepipeline get-pipeline-state --name "$StackName-web-frontend-pipeline" --query 'stageStates[*].{Stage:stageName,Status:latestExecution.status}' --output table 2>$null
    if ($webStatus) {
        $webStatus -split "`n" | ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Host "    Pipeline not found" -ForegroundColor Red
    }
}
catch {
    Write-Host "    Error checking pipeline status" -ForegroundColor Red
}

Write-Host ""
Write-Host "🏒 Quick Commands:" -ForegroundColor Green
Write-Host "  GitHub Actions: https://github.com/$GitHubOrg/$GitHubRepo/actions" -ForegroundColor White
Write-Host "  CodePipeline: https://console.aws.amazon.com/codesuite/codepipeline/pipelines" -ForegroundColor White