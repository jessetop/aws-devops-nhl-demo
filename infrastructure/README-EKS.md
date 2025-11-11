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

## EKS Version Behavior

**Expected Behavior**: The script may detect a newer EKS version (e.g., 1.34) but eksctl creates the cluster with an older version (e.g., 1.32).

**This is normal and intentional**:
- AWS API reports all available versions
- eksctl only supports versions it has tested
- eksctl automatically uses the highest version it supports
- This prevents deployment of potentially unstable versions

**Example Output**:
```
Getting latest EKS version...
Using EKS version: 1.34
Creating EKS cluster with eksctl...
# Cluster actually created with 1.32 (eksctl's latest supported)
```

This is **defense in depth** - the script aims for the latest, but eksctl ensures stability.