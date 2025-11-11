# NHL Stats DevOps Pipeline Demo - Project Overview

## Architecture Overview

### Microservices
- **NHL API Service** (Lambda) - Fetches NHL team and player statistics
- **Stats Processing Service** (EKS) - Processes and aggregates hockey data  
- **Web Frontend** (Lambda) - Interactive dashboard displaying stats

### CI/CD Pipelines
- **GitHub Actions** - NHL API Service deployment
- **AWS CodePipeline** - Stats Processing Service (EKS deployment)
- **AWS CodePipeline** - Web Frontend deployment

## Key Infrastructure Components

### Core Files
- **linux/setup-infrastructure.sh**: Main Linux deployment script with named parameter parsing, tool auto-installation, error handling, stack cleanup logic, GitHub token validation, and comprehensive resource conflict detection
- **windows/windows-setup-infrastructure.ps1**: Windows PowerShell equivalent with same functionality including token validation and resource conflict handling
- **infrastructure/codepipeline-stack.yaml**: CloudFormation template for CodePipeline with unique resource naming, EKS deploy stage, conditional resource creation parameters, and Amazon Linux 2 container images
- **infrastructure/github-oidc-role.yaml**: OIDC role template for secure GitHub Actions authentication
- **infrastructure/eks-cluster.yaml & eks-cluster-default-vpc.yaml**: eksctl configuration files for EKS deployment

### Service Components
- **.github/workflows/nhl-api-deploy.yml**: GitHub Actions workflow for NHL API service deployment using OIDC authentication
- **web-frontend/app.py**: Lambda function serving HTML dashboard with JavaScript to call real NHL API and EKS services, includes UTF-8 encoding fixes and HTML entity emojis
- **stats-processing-service/app.py**: Flask application that processes NHL team data from NHL Stats API
- **stats-processing-service/k8s-deployment.yaml**: Kubernetes deployment and service manifests for stats processing application

## Security Features
- **IAM Roles** - Least privilege access
- **VPC** - Private subnets for EKS
- **GitHub OIDC** - Secure authentication without long-term keys
- **ECR** - Private container registry

## Educational Value
- Demonstrates modern DevOps practices
- Multi-platform deployment scripts
- Cross-service integration patterns
- Real-world CI/CD pipeline examples