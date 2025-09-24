# MLOps Engineer Test Task: Nomad Cluster on AWS
# Main Terraform configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "nomad-cluster"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local values
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  azs         = slice(data.aws_availability_zones.available.names, 0, 3)
  
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  
  tags = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"
  
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  
  tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "./modules/iam"
  
  name_prefix = local.name_prefix
  
  tags = local.common_tags
}

# Key Pair
resource "tls_private_key" "nomad_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "nomad_key" {
  key_name   = "${local.name_prefix}-key"
  public_key = tls_private_key.nomad_key.public_key_openssh
}

# Store private key in SSM Parameter Store
resource "aws_ssm_parameter" "nomad_private_key" {
  name  = "/${local.name_prefix}/ssh/private-key"
  type  = "SecureString"
  value = tls_private_key.nomad_key.private_key_pem
  
  tags = local.common_tags
}

# Nomad Server Module
module "nomad_server" {
  source = "./modules/nomad-server"
  
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  
  security_group_ids = [
    module.security_groups.nomad_server_sg_id,
    module.security_groups.ssh_sg_id
  ]
  
  iam_instance_profile = module.iam.nomad_server_instance_profile_name
  key_name            = aws_key_pair.nomad_key.key_name
  
  instance_type = var.nomad_server_instance_type
  instance_count = var.nomad_server_count
  
  tags = local.common_tags
}

# Nomad Client Module
module "nomad_client" {
  source = "./modules/nomad-client"
  
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  
  security_group_ids = [
    module.security_groups.nomad_client_sg_id,
    module.security_groups.ssh_sg_id
  ]
  
  iam_instance_profile = module.iam.nomad_client_instance_profile_name
  key_name            = aws_key_pair.nomad_key.key_name
  
  instance_type = var.nomad_client_instance_type
  min_size      = var.nomad_client_min_size
  max_size      = var.nomad_client_max_size
  desired_size  = var.nomad_client_desired_size
  
  nomad_servers = module.nomad_server.private_ips
  
  tags = local.common_tags
}

# Application Load Balancer Module
module "alb" {
  source = "./modules/alb"
  
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet_ids
  
  security_group_ids = [module.security_groups.alb_sg_id]
  
  nomad_servers = module.nomad_server.private_ips
  
  certificate_arn = var.certificate_arn
  
  tags = local.common_tags
}

# Observability Module
module "observability" {
  source = "./modules/observability"
  
  name_prefix = local.name_prefix
  
  nomad_server_log_group = module.nomad_server.log_group_name
  nomad_client_log_group = module.nomad_client.log_group_name
  
  tags = local.common_tags
}

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "nomad_ui_url" {
  description = "URL to access Nomad UI"
  value       = "https://${module.alb.dns_name}"
}

output "nomad_servers" {
  description = "Nomad server private IPs"
  value       = module.nomad_server.private_ips
}

output "nomad_clients" {
  description = "Nomad client auto scaling group name"
  value       = module.nomad_client.asg_name
}

output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.nomad_key.key_name
}

output "private_key_parameter" {
  description = "SSM parameter name for private key"
  value       = aws_ssm_parameter.nomad_private_key.name
  sensitive   = true
}
