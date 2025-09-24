#!/bin/bash

# Nomad Cluster Destruction Script
# This script destroys the Nomad cluster infrastructure

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

# Function to confirm destruction
confirm_destruction() {
    print_warning "This will destroy all infrastructure and data!"
    print_warning "This action cannot be undone."
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Destruction cancelled."
        exit 0
    fi
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_status "Destroying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform..."
        terraform init
    fi
    
    # Plan destruction
    print_status "Planning Terraform destruction..."
    terraform plan -destroy -out=destroy.tfplan
    
    # Apply destruction
    print_status "Destroying infrastructure..."
    terraform apply destroy.tfplan
    
    print_success "Infrastructure destroyed successfully!"
    
    cd ..
}

# Function to cleanup ECR repository
cleanup_ecr() {
    print_status "Cleaning up ECR repository..."
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region)
    ECR_REPOSITORY="nomad-hello-world"
    ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    # Check if repository exists
    if aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION >/dev/null 2>&1; then
        print_status "Deleting ECR repository..."
        aws ecr delete-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION --force
        print_success "ECR repository deleted successfully!"
    else
        print_status "ECR repository does not exist, skipping..."
    fi
}

# Function to cleanup CloudWatch logs
cleanup_logs() {
    print_status "Cleaning up CloudWatch log groups..."
    
    # List of log groups to delete
    LOG_GROUPS=(
        "/aws/ec2/nomad-cluster-prod-nomad-server"
        "/aws/ec2/nomad-cluster-prod-nomad-client"
    )
    
    for log_group in "${LOG_GROUPS[@]}"; do
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --query 'logGroups[].logGroupName' --output text | grep -q "$log_group"; then
            print_status "Deleting log group: $log_group"
            aws logs delete-log-group --log-group-name "$log_group" || true
        fi
    done
    
    print_success "CloudWatch log groups cleaned up!"
}

# Main function
main() {
    print_status "Starting Nomad cluster destruction..."
    echo ""
    
    confirm_destruction
    
    destroy_infrastructure
    cleanup_ecr
    cleanup_logs
    
    print_success "🎉 Destruction completed successfully!"
    print_status "All resources have been cleaned up."
}

# Run main function
main "$@"
