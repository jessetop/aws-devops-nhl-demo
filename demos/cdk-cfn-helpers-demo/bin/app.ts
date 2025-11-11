#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CfnHelpersStack } from '../lib/cfn-helpers-stack';

const app = new cdk.App();

new CfnHelpersStack(app, 'CdkCfnHelpersDemo', {
  description: 'CDK version of CloudFormation Helper Scripts Demo - Teaching Example',
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
});