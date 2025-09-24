# Nomad Server Module

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "nomad_server" {
  name              = "/aws/ec2/${var.name_prefix}-nomad-server"
  retention_in_days = 30

  tags = var.tags
}

# User Data Script
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    log_group_name = aws_cloudwatch_log_group.nomad_server.name
    region         = data.aws_region.current.name
    server_count   = var.instance_count
    NOMAD_VERSION  = "1.6.2"
    CONSUL_VERSION = "1.16.2"
  }))
}

# Launch Template
resource "aws_launch_template" "nomad_server" {
  name_prefix   = "${var.name_prefix}-nomad-server-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  user_data = local.user_data

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-nomad-server"
      Type = "nomad-server"
    })
  }

  tags = var.tags
}

# Auto Scaling Group
resource "aws_autoscaling_group" "nomad_server" {
  name                = "${var.name_prefix}-nomad-server"
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = []
  health_check_type   = "EC2"
  health_check_grace_period = 300

  min_size         = var.instance_count
  max_size         = var.instance_count
  desired_capacity = var.instance_count

  launch_template {
    id      = aws_launch_template.nomad_server.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-nomad-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "Type"
    value               = "nomad-server"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Data sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_region" "current" {}

# Output the private IPs
data "aws_instances" "nomad_servers" {
  instance_tags = {
    Type = "nomad-server"
  }
  depends_on = [aws_autoscaling_group.nomad_server]
}
