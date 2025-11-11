# Infrastructure Setup & Deployment Scripts

## Cross-Platform Deployment Scripts

### Key Features
- **Tool Auto-Installation**: Scripts automatically detect and install missing tools (eksctl, kubectl) to reduce setup friction
- **Parameter Flexibility**: Named parameter parsing with validation
- **Error Handling**: Comprehensive error checking and rollback capabilities
- **Resource Conflict Detection**: Checks for existing resources and handles conflicts gracefully

### Windows PowerShell Script
- **File**: `windows/windows-setup-infrastructure.ps1`
- **Features**: GitHub token validation, stack cleanup logic, resource existence checking
- **Usage**: `.\windows\windows-setup-infrastructure.ps1 -GitHubOrg "jessetop" -GitHubToken "your-token"`

### Linux Bash Script  
- **File**: `linux/setup-infrastructure.sh`
- **Features**: Same functionality as Windows version with bash-specific implementations
- **Usage**: `./linux/setup-infrastructure.sh jessetop aws-devops-nhl-demo your-github-token`

## EKS Integration Improvements

### Migration from CloudFormation to eksctl
- **Reason**: More reliable EKS cluster management
- **Benefits**: Dynamic version detection, better VPC handling
- **Files**: `infrastructure/eks-cluster.yaml` and `eks-cluster-default-vpc.yaml`

### Version Management
- **Behavior**: Scripts detect latest AWS-supported EKS version but eksctl uses its own compatibility matrix
- **Result**: Potentially different deployed versions (intentional safety behavior)
- **Default VPC**: Command-line approach more reliable than YAML configuration

## Resource Naming Strategy

### Stack-Name Prefixed Naming
- **Purpose**: Enable multiple isolated deployments without conflicts
- **Implementation**: All resources use configurable stack-name prefixes
- **Benefits**: Multiple developers can deploy simultaneously

## Security Implementation

### GitHub OIDC Authentication
- **Purpose**: Avoid long-term AWS access keys
- **Implementation**: `infrastructure/github-oidc-role.yaml`
- **Fallback**: CLI creation due to regional CloudFormation limitations
- **Integration**: Uses OAuth method for GitHub connections