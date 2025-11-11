# Service Integration & Live Data Implementation

## Live Data Integration

### NHL API Service Integration
- **Migration**: Updated web frontend from mock data to real NHL API Lambda calls
- **Implementation**: JavaScript fetch calls to API Gateway endpoints
- **Data Source**: NHL Stats API via Lambda function
- **Deployment**: GitHub Actions pipeline with OIDC authentication

### EKS Stats Processing Integration
- **Service**: Flask application running on Amazon EKS
- **Data Processing**: Aggregates and processes NHL team data
- **Kubernetes**: 2 replicas with LoadBalancer service
- **Deployment**: CodePipeline with ECR and kubectl

## Web Frontend Enhancements

### Real Service Calls
- **File**: `web-frontend/app.py`
- **Features**: Interactive dashboard with live API calls
- **Error Handling**: Graceful fallbacks for service unavailability
- **Status Monitoring**: Service health checks and status display

### UTF-8 Encoding Fixes
- **Issue**: Emoji rendering problems in HTML output
- **Solution**: Added UTF-8 meta tag and charset specification
- **Implementation**: HTML entities for emojis, proper Content-Type headers

## Service Architecture

### NHL API Service (Lambda + GitHub Actions)
- **Runtime**: Python 3.9
- **Trigger**: API Gateway
- **Data Source**: NHL Stats API
- **Pipeline**: GitHub Actions on push to main branch

### Stats Processing Service (EKS + CodePipeline)  
- **Runtime**: Python Flask in Docker
- **Platform**: Amazon EKS with LoadBalancer
- **Scaling**: 2 replicas for high availability
- **Pipeline**: CodePipeline with ECR integration

### Web Frontend (Lambda + CodePipeline)
- **Runtime**: Python 3.9 serving HTML
- **Features**: Interactive dashboard, service status monitoring
- **Pipeline**: CodePipeline with CloudFormation deployment

## Cross-Service Communication

### API Endpoints
- **NHL API**: API Gateway URL for team statistics
- **Stats Processing**: EKS LoadBalancer URL for processed data
- **Web Frontend**: Lambda function URL for dashboard access

### Error Handling
- **Network Failures**: Graceful degradation with error messages
- **Service Unavailable**: Clear user feedback and retry suggestions
- **CORS**: Proper headers for cross-origin requests

## Development Workflow

### Local Testing
```bash
# Test NHL API locally
cd nhl-api-service
sam local start-api

# Test Stats Processing locally  
cd stats-processing-service
docker build -t stats-processing .
docker run -p 5000:5000 stats-processing
```

### Deployment Process
1. Push changes to GitHub
2. Pipelines trigger automatically
3. Monitor deployment in AWS Console
4. Verify service endpoints and functionality