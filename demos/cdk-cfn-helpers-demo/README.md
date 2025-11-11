# CDK CloudFormation Helper Scripts Demo

## Purpose
This is a **CDK version** of the CloudFormation helper scripts demo, showing the same functionality implemented using AWS CDK instead of pure CloudFormation templates.

## Comparison: CDK vs CloudFormation

| Aspect | CDK Version | CloudFormation Version |
|--------|-------------|------------------------|
| **Language** | TypeScript | YAML |
| **Metadata** | Escape hatch required | Native support |
| **Type Safety** | ✅ Compile-time checks | ❌ Runtime only |
| **Reusability** | ✅ Constructs & classes | ❌ Copy/paste |
| **Learning Curve** | Higher (programming) | Lower (declarative) |
| **Debugging** | Better IDE support | Template validation |

## What Both Versions Demonstrate

### 🔧 cfn-init
- Installs packages (Apache, wget)
- Creates configuration files
- Runs setup commands

### 📡 cfn-signal  
- Signals deployment success/failure
- Uses CreationPolicy for synchronization

### 📋 cfn-get-metadata
- Retrieves resource metadata dynamically
- Demo script included

### 🔄 cfn-hup
- Monitors for metadata changes
- Auto-reloads configuration

## Prerequisites

```bash
# Install Node.js and npm
npm install -g aws-cdk

# Install dependencies
cd cdk-cfn-helpers-demo
npm install
```

## Deployment

```bash
# Bootstrap CDK (first time only)
cdk bootstrap

# Deploy the stack
cdk deploy

# View differences before deploy
cdk diff

# Destroy when done
cdk destroy
```

## Key CDK Concepts Demonstrated

### 1. Escape Hatch for CloudFormation Features
```typescript
// Access underlying CloudFormation resource
const cfnInstance = instance.node.defaultChild as ec2.CfnInstance;

// Add CloudFormation-specific metadata
cfnInstance.addMetadata('AWS::CloudFormation::Init', { ... });
```

### 2. Type-Safe Infrastructure
```typescript
// Compile-time validation
const instance = new ec2.Instance(this, 'MyInstance', {
  instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO)
});
```

### 3. Reusable Constructs
```typescript
// Could be extracted into reusable construct
class CfnHelperInstance extends Construct { ... }
```

## Educational Value

This demo shows:
- **Same end result** using different tools
- **CDK advantages**: Type safety, IDE support, reusability
- **CloudFormation advantages**: Simpler for basic use cases
- **When to use each approach**

Perfect for teaching **infrastructure as code** trade-offs! 🎓