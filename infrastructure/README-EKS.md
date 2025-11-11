# EKS Deployment Methods

## Current: eksctl (Recommended)
- **File**: `eks-cluster.yaml`
- **Tool**: eksctl
- **Benefits**: 
  - Auto-installs add-ons (VPC CNI, CoreDNS, kube-proxy, EBS CSI)
  - Simpler configuration
  - Better defaults
  - Automatic VPC creation
  - Built-in best practices

## Archived: CloudFormation
- **File**: `eks-cluster-archived.yaml`
- **Tool**: CloudFormation
- **Status**: Archived for reference
- **Reason**: More complex, manual add-on management required

## Prerequisites for eksctl
```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Windows (chocolatey)
choco install eksctl
```