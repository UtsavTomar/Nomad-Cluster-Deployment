# MLOps Engineer Test Task: Nomad Cluster Configuration
# Copy this file to terraform.tfvars and customize the values

aws_region = "us-west-2"
project_name = "nomad-cluster"
environment = "prod"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]

# Nomad Server Configuration
nomad_server_instance_type = "t3.micro"
nomad_server_count = 3

# Nomad Client Configuration
nomad_client_instance_type = "t3.small"
nomad_client_min_size = 1
nomad_client_max_size = 3
nomad_client_desired_size = 1

