# MLOps Engineer Test Task: Nomad Cluster Variables

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "nomad-cluster"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

variable "nomad_server_instance_type" {
  description = "Instance type for Nomad servers"
  type        = string
  default     = "t3.micro"
}

variable "nomad_server_count" {
  description = "Number of Nomad servers"
  type        = number
  default     = 3
}

variable "nomad_client_instance_type" {
  description = "Instance type for Nomad clients"
  type        = string
  default     = "t3.small"
}

variable "nomad_client_min_size" {
  description = "Minimum number of Nomad clients"
  type        = number
  default     = 1
}

variable "nomad_client_max_size" {
  description = "Maximum number of Nomad clients"
  type        = number
  default     = 3
}

variable "nomad_client_desired_size" {
  description = "Desired number of Nomad clients"
  type        = number
  default     = 1
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for ALB"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the Nomad UI"
  type        = string
  default     = ""
}
