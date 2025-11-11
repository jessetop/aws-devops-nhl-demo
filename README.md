# NHL Stats DevOps Pipeline Demo 🏒

A comprehensive DevOps demonstration featuring multiple microservices, CI/CD pipelines, and AWS services for displaying NHL hockey statistics.

## Architecture Overview

### Microservices
- **NHL API Service** (Lambda) - Fetches NHL team and player statistics
- **Stats Processing Service** (EKS) - Processes and aggregates hockey data
- **Web Frontend** (Lambda) - Interactive dashboard displaying stats

### CI/CD Pipelines
- **GitHub Actions** - NHL API Service deployment
- **AWS CodePipeline** - Stats Processing Service (EKS deployment)
- **AWS CodePipeline** - Web Frontend deployment

## Quick Start

### Prerequisites
- AWS CLI configured
- SAM CLI installed
- Docker installed
- kubectl installed
- GitHub account with repository

### 1. Deploy Infrastructure

**Windows (PowerShell):**
```powershell
# Clone and navigate to project
git clone https://github.com/jessetop/aws-devops-nhl-demo
cd aws-devops-nhl-demo

# Deploy using PowerShell script
.\windows\windows-setup-infrastructure.ps1 -GitHubOrg "jessetop" -GitHubToken "your-github-token"
```

**Linux/macOS (Bash):**
```bash
# Clone and navigate to project
git clone https://github.com/jessetop/aws-devops-nhl-demo
cd aws-devops-nhl-demo

# Make scripts executable and deploy
chmod +x linux/*.sh
./linux/setup-infrastructure.sh jessetop aws-devops-nhl-demo your-github-token
```

### 2. Configure GitHub Secrets
Add these secrets to your GitHub repository:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 3. Configure EKS

**Windows:**
```powershell
.\windows\windows-deploy-to-eks.ps1
```

**Linux/macOS:**
```bash
./linux/deploy-to-eks.sh
```

## Service Details

### NHL API Service (Lambda + GitHub Actions)
- **Runtime**: Python 3.9
- **Trigger**: API Gateway
- **Data Source**: NHL Stats API
- **Deployment**: GitHub Actions on push to main

### Stats Processing Service (EKS + CodePipeline)
- **Runtime**: Python Flask in Docker
- **Platform**: Amazon EKS
- **Scaling**: 2 replicas with LoadBalancer
- **Deployment**: CodePipeline with ECR

### Web Frontend (Lambda + CodePipeline)
- **Runtime**: Python 3.9 serving HTML
- **Features**: Interactive dashboard, service status
- **Deployment**: CodePipeline with CloudFormation

## Pipeline Triggers

### GitHub Actions (NHL API)
- Triggers on push to `main` branch
- Path filter: `nhl-api-service/**`
- Manual trigger available

### CodePipeline (Stats Processing)
- Triggers on GitHub webhook
- Builds Docker image
- Pushes to ECR
- Updates EKS deployment

### CodePipeline (Web Frontend)
- Triggers on GitHub webhook
- Builds SAM application
- Deploys via CloudFormation

## Monitoring & Observability

- **CloudWatch Logs** - All services log to CloudWatch
- **EKS Monitoring** - Container Insights enabled
- **API Gateway** - Request/response logging
- **Pipeline Status** - CodePipeline console

## Cost Optimization

- **Lambda** - Pay per request
- **EKS** - t3.medium nodes (1-3 instances)
- **ECR** - Lifecycle policies for image cleanup
- **S3** - Versioning for artifacts

## Security Features

- **IAM Roles** - Least privilege access
- **VPC** - Private subnets for EKS
- **Secrets** - GitHub tokens in parameters
- **ECR** - Private container registry

## Development Workflow

1. **Local Development**
   ```bash
   # Test NHL API locally
   cd nhl-api-service
   sam local start-api
   
   # Test Stats Processing locally
   cd stats-processing-service
   docker build -t stats-processing .
   docker run -p 5000:5000 stats-processing
   ```

2. **Deploy Changes**
   - Push to GitHub triggers pipelines
   - Monitor in AWS Console
   - Check service endpoints

## Troubleshooting

### Common Issues
- **GitHub Actions failing**: Check AWS credentials in secrets
- **EKS deployment issues**: Verify kubectl configuration
- **Pipeline failures**: Check CodeBuild logs in CloudWatch
- **EKS version mismatch**: Script detects latest AWS version but eksctl uses highest supported version (this is normal and safer)

### Useful Commands
```bash
# Check EKS cluster status
kubectl get nodes

# View service logs
kubectl logs -l app=stats-processing

# Check pipeline status
aws codepipeline get-pipeline-state --name stats-processing-pipeline
```

## Cleanup

```bash
# Delete CloudFormation stacks (replace nhl-stats with your stack name)
aws cloudformation delete-stack --stack-name nhl-stats-codepipeline
aws cloudformation delete-stack --stack-name nhl-stats-oidc-role
eksctl delete cluster --name nhl-stats-cluster
aws cloudformation delete-stack --stack-name nhl-api-service
aws cloudformation delete-stack --stack-name nhl-stats-web-frontend-stack
```

## Educational Demos

See the `demos/` folder for additional learning examples:
- **CloudFormation Helper Scripts** - cfn-init, cfn-signal, cfn-get-metadata, cfn-hup
- **CDK vs CloudFormation** - Same functionality, different approaches

## Next Steps

- Add automated testing stages
- Implement blue/green deployments
- Add monitoring dashboards
- Integrate with AWS X-Ray for tracing
- Add database layer for stats storage