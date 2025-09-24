#!/bin/bash

# Nomad Cluster Deployment Script
# This script deploys the Nomad cluster infrastructure and applications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_deps=()
    
    if ! command_exists terraform; then
        missing_deps+=("terraform")
    fi
    
    if ! command_exists aws; then
        missing_deps+=("aws-cli")
    fi
    
    if ! command_exists docker; then
        missing_deps+=("docker")
    fi
    
    if ! command_exists nomad; then
        missing_deps+=("nomad")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_error "Please install the missing dependencies and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to check AWS credentials
check_aws_credentials() {
    print_status "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured or invalid"
        print_error "Please run 'aws configure' to set up your credentials"
        exit 1
    fi
    
    print_success "AWS credentials are valid"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    print_status "Applying Terraform deployment..."
    terraform apply tfplan
    
    # Get outputs
    print_status "Getting infrastructure outputs..."
    NOMAD_UI_URL=$(terraform output -raw nomad_ui_url)
    NOMAD_SERVERS=$(terraform output -json nomad_servers)
    
    print_success "Infrastructure deployed successfully!"
    print_status "Nomad UI URL: $NOMAD_UI_URL"
    
    cd ..
}

# Function to build and push application
build_application() {
    print_status "Building and pushing application..."
    
    cd apps/hello-world
    
    # Get AWS account ID and region
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region)
    ECR_REPOSITORY="nomad-hello-world"
    ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    # Login to ECR
    print_status "Logging in to Amazon ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
    
    # Create ECR repository if it doesn't exist
    print_status "Creating ECR repository if it doesn't exist..."
    aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION
    
    # Build and push image
    print_status "Building Docker image..."
    docker build -t $ECR_REPOSITORY:latest .
    docker tag $ECR_REPOSITORY:latest $ECR_REGISTRY/$ECR_REPOSITORY:latest
    
    print_status "Pushing Docker image to ECR..."
    docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
    
    # Update Nomad job with ECR image
    print_status "Updating Nomad job with ECR image..."
    sed -i "s|image = \".*\"|image = \"$ECR_REGISTRY/$ECR_REPOSITORY:latest\"|g" ../../jobs/hello-world.nomad
    
    print_success "Application built and pushed successfully!"
    
    cd ../..
}

# Function to deploy application to Nomad
deploy_application() {
    print_status "Deploying application to Nomad..."
    
    # Get Nomad server IP (first IP from the list)
    cd terraform
    NOMAD_SERVER_IP=$(terraform output nomad_servers | grep -o '"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"' | head -1 | tr -d '"')
    cd ..
    
    # Set Nomad address
    export NOMAD_ADDR="http://$NOMAD_SERVER_IP:4646"
    
    # Wait for Nomad to be ready
    print_status "Waiting for Nomad to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if nomad server members >/dev/null 2>&1; then
            print_success "Nomad is ready!"
            break
        fi
        
        print_status "Attempt $attempt/$max_attempts: Waiting for Nomad..."
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Nomad is not ready after $max_attempts attempts"
        exit 1
    fi
    
    # Deploy the job
    print_status "Deploying hello-world job..."
    nomad job run jobs/hello-world.nomad
    
    # Wait for deployment
    print_status "Waiting for deployment to complete..."
    sleep 30
    
    # Check job status
    print_status "Checking job status..."
    nomad job status hello-world
    
    print_success "Application deployed successfully!"
}

# Function to show access information
show_access_info() {
    print_status "Deployment complete! Here's how to access your resources:"
    echo ""
    echo "🌐 Nomad UI: $NOMAD_UI_URL"
    echo "📊 CloudWatch Dashboard: https://$AWS_REGION.console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards"
    echo "📝 Application Logs: https://$AWS_REGION.console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#logsV2:log-groups"
    echo ""
    echo "🔧 Useful Commands:"
    echo "  - Check Nomad status: nomad server members"
    echo "  - List jobs: nomad job status"
    echo "  - View job logs: nomad logs hello-world"
    echo "  - Scale job: nomad job scale hello-world 5"
    echo ""
}

# Main function
main() {
    print_status "Starting Nomad cluster deployment..."
    echo ""
    
    check_prerequisites
    check_aws_credentials
    deploy_infrastructure
    build_application
    deploy_application
    show_access_info
    
    print_success "🎉 Deployment completed successfully!"
}

# Run main function
main "$@"
