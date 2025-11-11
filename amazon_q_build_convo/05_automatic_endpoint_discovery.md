# Automatic Endpoint Discovery Implementation

## Problem Statement
Manual URL configuration in web frontend required developers to:
- Find API Gateway URLs after deployment
- Locate EKS LoadBalancer endpoints
- Manually update code with service URLs
- Redeploy after configuration changes

## Solution: Pipeline-Based Endpoint Discovery

### Implementation Overview
- **File**: `web-frontend/buildspec.yml`
- **Method**: Automatic discovery during CodePipeline build process
- **Result**: Zero-configuration service integration

### Discovery Process

#### NHL API Gateway Discovery
```bash
# Find API Gateway URL
NHL_API_URL=$(aws apigateway get-rest-apis --query 'items[?name==`nhl-api-service-api`].id' --output text)
NHL_ENDPOINT="https://${NHL_API_URL}.execute-api.${AWS_DEFAULT_REGION}.amazonaws.com/prod/nhl-stats"
```

#### EKS LoadBalancer Discovery
```bash
# Get EKS LoadBalancer URL
kubectl config update-cluster --name nhl-stats-cluster
STATS_ENDPOINT=$(kubectl get service stats-processing-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
STATS_URL="http://${STATS_ENDPOINT}/process-stats"
```

### Code Injection Process

#### Placeholder Replacement
- **Original**: `'https://YOUR_NHL_API_GATEWAY_URL/prod/nhl-stats'`
- **Replaced**: Actual API Gateway URL discovered during build
- **Method**: `sed` commands in buildspec to replace placeholders

#### Dynamic Configuration
```bash
# Replace placeholders in app.py
sed -i "s|https://YOUR_NHL_API_GATEWAY_URL/prod/nhl-stats|${NHL_ENDPOINT}|g" app.py
sed -i "s|http://YOUR_EKS_LOADBALANCER_URL/process-stats|${STATS_URL}|g" app.py
```

## Benefits

### Developer Experience
- **Zero Configuration**: No manual URL updates required
- **Automatic Updates**: Service URLs update automatically on redeployment
- **Error Reduction**: Eliminates manual configuration mistakes

### Operational Benefits
- **Environment Agnostic**: Works across different AWS accounts/regions
- **Scalable**: Supports multiple deployment environments
- **Maintainable**: Single source of truth for service discovery

## Implementation Details

### Build Process Integration
1. **Pre-build**: Install kubectl and configure EKS access
2. **Discovery**: Query AWS APIs for service endpoints
3. **Injection**: Replace placeholders in source code
4. **Build**: Continue with normal SAM build process
5. **Deploy**: Deploy with real service URLs embedded

### Error Handling
- **Service Not Found**: Graceful fallback to placeholder URLs
- **Network Issues**: Retry logic for API calls
- **Permission Issues**: Clear error messages for debugging

## Usage
After implementation, developers simply:
1. Commit code changes
2. Push to repository
3. Pipeline automatically discovers and injects current service URLs
4. Web frontend deployed with live service integration

## Future Enhancements
- **Service Discovery**: Implement AWS Service Discovery integration
- **Health Checks**: Add endpoint validation during discovery
- **Multi-Environment**: Support for dev/staging/prod endpoint discovery
- **Caching**: Cache discovered endpoints to reduce API calls