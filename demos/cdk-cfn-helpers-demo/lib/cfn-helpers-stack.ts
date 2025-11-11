import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export class CfnHelpersStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Parameter for stack naming consistency
    const stackName = new cdk.CfnParameter(this, 'StackName', {
      type: 'String',
      default: 'nhl-stats',
      description: 'Stack name prefix for unique resource naming'
    });

    // IAM Role for the instance
    const instanceRole = new iam.Role(this, 'CFNHelperInstanceRole', {
      roleName: `${stackName.valueAsString}-CDK-CFNHelperInstanceRole`,
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('CloudWatchAgentServerPolicy')
      ],
      inlinePolicies: {
        CFNHelperPolicy: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              effect: iam.Effect.ALLOW,
              actions: [
                'cloudformation:SignalResource',
                'cloudformation:DescribeStackResource',
                'cloudformation:DescribeStackResources'
              ],
              resources: ['*']
            })
          ]
        })
      }
    });

    // Security Group
    const securityGroup = new ec2.SecurityGroup(this, 'CFNHelperSecurityGroup', {
      vpc: ec2.Vpc.fromLookup(this, 'DefaultVPC', { isDefault: true }),
      description: 'Security group for CDK CFN helpers demo instance',
      securityGroupName: `${stackName.valueAsString}-cdk-cfn-helpers-sg`
    });

    securityGroup.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(80),
      'HTTP access to demo page'
    );

    securityGroup.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(22),
      'SSH access for debugging'
    );

    // User Data script - same logic as CloudFormation version
    const userData = ec2.UserData.forLinux();
    userData.addCommands(
      '#!/bin/bash',
      'yum update -y',
      '',
      '# Install CloudFormation helper scripts (pre-installed on Amazon Linux)',
      '# cfn-init: Reads and processes metadata from CloudFormation template',
      '# cfn-signal: Signals CloudFormation about resource status', 
      '# cfn-get-metadata: Retrieves metadata for a resource',
      '# cfn-hup: Daemon that detects changes in resource metadata',
      '',
      '# 1. CFN-INIT: Initialize the instance based on metadata',
      `/opt/aws/bin/cfn-init -v \\`,
      `  --stack ${this.stackName} \\`,
      `  --resource CFNHelpersDemoInstance \\`,
      `  --configsets InstallAndRun \\`,
      `  --region ${this.region}`,
      '',
      '# 2. CFN-SIGNAL: Signal success/failure back to CloudFormation',
      `/opt/aws/bin/cfn-signal -e $? \\`,
      `  --stack ${this.stackName} \\`,
      `  --resource CFNHelpersDemoInstance \\`,
      `  --region ${this.region}`
    );

    // EC2 Instance with CloudFormation Init metadata
    const instance = new ec2.Instance(this, 'CFNHelpersDemoInstance', {
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
      machineImage: ec2.MachineImage.latestAmazonLinux2023(),
      vpc: ec2.Vpc.fromLookup(this, 'VPC', { isDefault: true }),
      role: instanceRole,
      securityGroup: securityGroup,
      userData: userData
    });

    // Add CloudFormation Init metadata using escape hatch
    const cfnInstance = instance.node.defaultChild as ec2.CfnInstance;
    
    cfnInstance.addMetadata('AWS::CloudFormation::Init', {
      configSets: {
        InstallAndRun: ['Install', 'Configure', 'Services']
      },
      Install: {
        packages: {
          yum: {
            httpd: [],
            wget: []
          }
        },
        files: {
          '/var/www/html/index.html': {
            content: cdk.Fn.sub(`<!DOCTYPE html>
<html>
<head><title>CDK CFN Helper Scripts Demo</title></head>
<body>
  <h1>🏒 NHL Stats - CDK CloudFormation Helper Scripts Demo</h1>
  <h2>This instance demonstrates (using CDK):</h2>
  <ul>
    <li><strong>cfn-init</strong>: Installed Apache, created this page</li>
    <li><strong>cfn-signal</strong>: Signaled successful initialization</li>
    <li><strong>cfn-get-metadata</strong>: Can retrieve this metadata</li>
    <li><strong>cfn-hup</strong>: Monitors for template changes</li>
  </ul>
  <p><strong>Deployment Method:</strong> AWS CDK (vs pure CloudFormation)</p>
  <p>Stack: \${AWS::StackName}</p>
  <p>Region: \${AWS::Region}</p>
  <p>Instance ID: <span id="instance-id">Loading...</span></p>
  <script>
    fetch('http://169.254.169.254/latest/meta-data/instance-id')
      .then(r => r.text())
      .then(id => document.getElementById('instance-id').textContent = id);
  </script>
</body>
</html>`),
            mode: '000644',
            owner: 'root',
            group: 'root'
          },
          '/etc/cfn/cfn-hup.conf': {
            content: cdk.Fn.sub(`[main]
stack=\${AWS::StackName}
region=\${AWS::Region}
# CFN-HUP: Detects changes in resource metadata
# Polls CloudFormation every 15 minutes for changes
interval=15`),
            mode: '000400',
            owner: 'root',
            group: 'root'
          },
          '/etc/cfn/hooks.d/cfn-auto-reloader.conf': {
            content: cdk.Fn.sub(`[cfn-auto-reloader-hook]
triggers=post.update
path=Resources.CFNHelpersDemoInstance.Metadata.AWS::CloudFormation::Init
# When metadata changes, re-run cfn-init
action=/opt/aws/bin/cfn-init -v --stack \${AWS::StackName} --resource CFNHelpersDemoInstance --configsets InstallAndRun --region \${AWS::Region}
runas=root`),
            mode: '000400',
            owner: 'root',
            group: 'root'
          },
          '/home/ec2-user/demo-get-metadata.sh': {
            content: cdk.Fn.sub(`#!/bin/bash
echo "=== CDK CFN-GET-METADATA Demo ==="
echo "Retrieving metadata for this instance..."

# CFN-GET-METADATA: Retrieve metadata for a resource
/opt/aws/bin/cfn-get-metadata \\
  --stack \${AWS::StackName} \\
  --resource CFNHelpersDemoInstance \\
  --region \${AWS::Region}

echo ""
echo "=== Instance Metadata ==="
curl -s http://169.254.169.254/latest/meta-data/instance-id
echo ""`),
            mode: '000755',
            owner: 'ec2-user',
            group: 'ec2-user'
          }
        }
      },
      Configure: {
        commands: {
          '01_enable_httpd': {
            command: 'systemctl enable httpd'
          },
          '02_start_httpd': {
            command: 'systemctl start httpd'
          }
        }
      },
      Services: {
        sysvinit: {
          httpd: {
            enabled: true,
            ensureRunning: true
          },
          'cfn-hup': {
            enabled: true,
            ensureRunning: true,
            files: [
              '/etc/cfn/cfn-hup.conf',
              '/etc/cfn/hooks.d/cfn-auto-reloader.conf'
            ]
          }
        }
      }
    });

    // Creation Policy - wait for cfn-signal
    cfnInstance.cfnOptions.creationPolicy = {
      resourceSignal: {
        timeout: 'PT15M',
        count: 1
      }
    };

    // Tags
    cdk.Tags.of(instance).add('Name', `${stackName.valueAsString}-cdk-cfn-helpers-demo`);
    cdk.Tags.of(instance).add('Purpose', 'CDK CloudFormation Helper Scripts Demo');

    // Outputs
    new cdk.CfnOutput(this, 'DemoInstanceId', {
      description: 'Instance ID of the CDK CFN helpers demo',
      value: instance.instanceId
    });

    new cdk.CfnOutput(this, 'DemoWebsiteURL', {
      description: 'URL to view the CDK demo page',
      value: `http://${instance.instancePublicDnsName}`
    });

    new cdk.CfnOutput(this, 'SSHCommand', {
      description: 'SSH command to connect to the instance',
      value: `ssh -i your-key.pem ec2-user@${instance.instancePublicDnsName}`
    });

    new cdk.CfnOutput(this, 'GetMetadataCommand', {
      description: 'Command to run the cfn-get-metadata demo',
      value: '/home/ec2-user/demo-get-metadata.sh'
    });
  }
}