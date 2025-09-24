# Application Load Balancer Module for Nomad UI

# Application Load Balancer
resource "aws_lb" "nomad" {
  name               = "${var.name_prefix}-nomad-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = var.tags
}

# Target Group for Nomad Servers
resource "aws_lb_target_group" "nomad" {
  name     = "${var.name_prefix}-nomad-tg"
  port     = 4646
  protocol = "HTTP"
  vpc_id   = data.aws_subnet.main.vpc_id
  target_type = "ip"  # Use IP targets instead of instance targets

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 30
    path                = "/v1/status/peers"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = var.tags
}

# Target Group Attachment for Nomad Servers
# Use a static approach with 3 servers
resource "aws_lb_target_group_attachment" "nomad" {
  count = 3

  target_group_arn = aws_lb_target_group.nomad.arn
  target_id        = var.nomad_servers[count.index]
  port             = 4646

  # Only create if the server exists
  depends_on = [var.nomad_servers]
}

# HTTP Listener (forward to target group)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.nomad.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nomad.arn
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.nomad.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nomad.arn
  }
}

# Data sources
data "aws_subnet" "main" {
  id = var.subnet_ids[0]
}
