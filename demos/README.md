# DevOps Demos 🎓

This folder contains educational demos that showcase various AWS and DevOps concepts, separate from the main NHL Stats application.

## Available Demos

### 1. CloudFormation Helper Scripts Demo
**Location:** `cfn-helpers-demo.yaml`
**Purpose:** Demonstrates all four CloudFormation helper scripts in action

**What it shows:**
- `cfn-init` - Package installation and file creation
- `cfn-signal` - Success/failure signaling with CreationPolicy
- `cfn-get-metadata` - Dynamic metadata retrieval
- `cfn-hup` - Change detection and auto-reloading

**Deploy:**
```bash
aws cloudformation deploy \
  --template-file demos/cfn-helpers-demo.yaml \
  --stack-name cfn-helpers-demo \
  --capabilities CAPABILITY_NAMED_IAM
```

### 2. CDK CloudFormation Helper Scripts Demo
**Location:** `cdk-cfn-helpers-demo/`
**Purpose:** Same functionality as above, but implemented using AWS CDK

**What it shows:**
- CDK vs CloudFormation comparison
- Type-safe infrastructure as code
- Escape hatches for CloudFormation features
- Reusable constructs and patterns

**Deploy:**
```bash
cd demos/cdk-cfn-helpers-demo
npm install
cdk deploy
```

## Educational Value

These demos are perfect for:
- **Teaching CloudFormation concepts**
- **Comparing IaC approaches** (CloudFormation vs CDK)
- **Understanding helper scripts** in real scenarios
- **Hands-on learning** with working examples

## Separation from Main App

These demos are intentionally separate from the NHL Stats DevOps pipeline to:
- Keep the main application focused
- Provide standalone learning examples
- Allow independent deployment and testing
- Demonstrate concepts without complexity

## Next Steps

Consider adding more demos for:
- AWS Systems Manager
- CodeDeploy blue/green deployments
- Lambda deployment patterns
- Container orchestration examples