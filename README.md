# MLOps Engineer: Nomad Cluster Deployment

This repository contains a complete HashiCorp Nomad cluster deployment on AWS using Terraform, designed to meet all core requirements and bonus objectives of the MLOps Engineer Test Task.

## Architecture Overview

### Infrastructure Components

- **VPC with Public/Private Subnets**: Secure network isolation with NAT gateways for outbound internet access
- **3 Nomad Servers**: High availability cluster in private subnets across 3 AZs
- **Auto Scaling Group for Nomad Clients**: Scalable compute nodes for workload execution
- **Application Load Balancer (ALB)**: Secure access to Nomad UI with HTTPS support
- **CloudWatch Integration**: Comprehensive logging and monitoring
- **ECR Integration**: Container registry for application images
- **IAM Roles & Security Groups**: Least privilege access and network security

### Design Choices

1. **High Availability**: 3 Nomad servers across multiple AZs for fault tolerance
2. **Security First**: Private subnets for servers, ALB for secure UI access, least privilege IAM
3. **Cost Optimized**: t3.micro servers and t3.small clients for cost efficiency
4. **Observability**: CloudWatch logs, metrics, and dashboards for monitoring
5. **Scalability**: Auto Scaling Groups for easy client node scaling

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Docker
- HashiCorp Nomad CLI
- Git

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd mlops
```

### 2. Configure AWS Credentials

```bash
aws configure
```

### 3. Deploy Infrastructure

```bash
./scripts/deploy.sh
```

This script will:
- Deploy the complete infrastructure using Terraform
- Build and push the hello-world Docker image to ECR
- Deploy the application to Nomad
- Provide access URLs and credentials

### 4. Access the Nomad UI

Once deployment is complete, access the Nomad UI at:
```
https://nomad-cluster-prod-nomad-alb-<id>.us-west-2.elb.amazonaws.com
```

## Manual Deployment Steps

If you prefer to deploy manually:

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Build and Push Application

```bash
# Login to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 587688724297.dkr.ecr.us-west-2.amazonaws.com

# Build and push image
docker build -t nomad-hello-world apps/hello-world/
docker tag nomad-hello-world:latest 587688724297.dkr.ecr.us-west-2.amazonaws.com/nomad-hello-world:latest
docker push 587688724297.dkr.ecr.us-west-2.amazonaws.com/nomad-hello-world:latest
```

### 3. Deploy Application to Nomad

```bash
# Set Nomad address
export NOMAD_ADDR="http://nomad-cluster-prod-nomad-alb-<id>.us-west-2.elb.amazonaws.com"

# Wait for Nomad to be ready (may take 5-10 minutes)
# Check status
nomad server members

# Deploy the application
nomad job run jobs/hello-world.nomad
```

## Project Structure

```
mlops/
├── apps/
│   └── hello-world/           # Sample web application
│       ├── Dockerfile
│       ├── package.json
│       └── server.js
├── jobs/
│   └── hello-world.nomad      # Nomad job specification
├── scripts/
│   ├── deploy.sh              # Automated deployment script
│   └── destroy.sh             # Cleanup script
├── terraform/
│   ├── main.tf                # Main Terraform configuration
│   ├── variables.tf           # Input variables
│   ├── terraform.tfvars       # Variable values
│   └── modules/               # Terraform modules
│       ├── alb/               # Application Load Balancer
│       ├── iam/               # IAM roles and policies
│       ├── nomad-server/      # Nomad server instances
│       ├── nomad-client/      # Nomad client instances
│       ├── observability/     # CloudWatch monitoring
│       ├── security-groups/   # Security group rules
│       └── vpc/               # VPC and networking
└── README.md                  # This file
```

## Core Requirements Met

✅ **Infrastructure as Code**: Complete Terraform implementation with modular structure
✅ **Cluster Topology**: 3 Nomad servers + scalable client nodes
✅ **Secure UI Access**: ALB with HTTPS support for Nomad UI
✅ **Workload Deployment**: Containerized hello-world application deployed as Nomad job

## Bonus Objectives Achieved

✅ **Automation**: Complete CI/CD pipeline with automated deployment script
✅ **Security**: 
   - Private subnets for servers
   - Security groups with least privilege
   - IAM roles with minimal permissions
   - HTTPS-enabled ALB
✅ **Observability**: 
   - CloudWatch logs for all components
   - Custom dashboards for monitoring
   - CPU and memory alarms
   - SNS notifications

## Monitoring and Observability

- **CloudWatch Dashboard**: `nomad-cluster-prod-nomad-dashboard`
- **Log Groups**: 
  - `/aws/ec2/nomad-cluster-prod-nomad-server`
  - `/aws/ec2/nomad-cluster-prod-nomad-client`
- **Alarms**: CPU utilization monitoring with auto-scaling

## Scaling the Cluster

To scale the Nomad client nodes:

```bash
cd terraform
terraform apply -var="nomad_client_desired_size=5"
```

## Cleanup

To destroy all resources:

```bash
./scripts/destroy.sh
```

Or manually:

```bash
cd terraform
terraform destroy
```

## Troubleshooting

### Nomad UI Not Accessible

If you get a 502 error, the Nomad servers may still be starting up. Wait 5-10 minutes and try again.

### Health Check Failures

The ALB health checks may fail initially while Nomad is starting. This is normal and will resolve once Nomad is fully operational.

### Application Not Deploying

Ensure Nomad is ready by checking:
```bash
nomad server members
```

## Security Considerations

- All servers run in private subnets
- ALB provides secure access to Nomad UI
- IAM roles follow least privilege principle
- Security groups restrict traffic to necessary ports only
- All traffic is encrypted in transit

## Cost Optimization

- t3.micro instances for Nomad servers
- t3.small instances for Nomad clients
- Auto Scaling Groups to scale based on demand
- NAT Gateway optimization across AZs

## Support

For issues or questions, please refer to the Terraform and Nomad documentation, or create an issue in this repository.