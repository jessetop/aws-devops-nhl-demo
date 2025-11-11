# Pipeline Troubleshooting & Resolution

## Common Pipeline Issues Resolved

### GitHub Token Validation
- **Issue**: Invalid or expired GitHub tokens causing pipeline failures
- **Solution**: Added comprehensive token validation in setup scripts
- **Implementation**: Scripts test token permissions before proceeding

### Path Corrections
- **Issue**: CodeBuild runs from repository root but services need to build from subdirectories
- **Solution**: Explicit directory changes in buildspec files
- **Files**: `stats-processing-service/buildspec.yml`, `stats-processing-service/deploy-buildspec.yml`

### IAM Permissions
- **Issue**: CloudFormation role needs broader permissions for SAM deployments
- **Solution**: Changed from PowerUserAccess to AdministratorAccess
- **Reason**: SAM templates create IAM roles requiring elevated permissions

### CloudFormation Capabilities
- **Issue**: Missing CAPABILITY_IAM for templates creating IAM resources
- **Solution**: Added proper capabilities to CloudFormation deployments
- **Impact**: Enables automatic IAM role creation

## EKS-Specific Challenges

### EKS Access Management
- **Issue**: CodeBuild role needs permissions to deploy to EKS
- **Solution**: Implemented EKS Access Entries with CLI-based fallback
- **Reason**: Modern EKS Access Entries not available in all regions via CloudFormation

### Container Image Compatibility
- **Issue**: Amazon Linux 2023 requires specific compute types
- **Solution**: Use Amazon Linux 2 with standard:5.0 and BUILD_GENERAL1_MEDIUM
- **Result**: Reliable builds across all regions

### YAML Embedding Complexity
- **Issue**: Complex YAML embedded in CloudFormation templates causes parsing issues
- **Solution**: Separate buildspec files instead of inline YAML
- **Files**: Created dedicated `buildspec.yml` and `deploy-buildspec.yml`

## Resource Conflict Handling

### Conditional CloudFormation Resources
- **Implementation**: Added existence checks for S3 buckets, ECR repositories, EKS clusters
- **Benefits**: Prevents deployment failures from existing resources
- **Method**: Conditional parameters and resource creation logic

### Stack Cleanup Logic
- **Purpose**: Clean rollback on deployment failures
- **Implementation**: Automated stack deletion with dependency ordering
- **Safety**: Preserves data while cleaning infrastructure

## Monitoring & Debugging

### Useful Commands
```bash
# Check EKS cluster status
kubectl get nodes

# View service logs  
kubectl logs -l app=stats-processing

# Check pipeline status
aws codepipeline get-pipeline-state --name stats-processing-pipeline
```

### Log Locations
- **CloudWatch Logs**: All services log to CloudWatch
- **CodeBuild Logs**: Available in CloudWatch for build troubleshooting
- **EKS Logs**: Container Insights enabled for monitoring