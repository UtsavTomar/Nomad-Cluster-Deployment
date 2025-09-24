# Application Load Balancer Module Outputs

output "dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.nomad.dns_name
}

output "zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.nomad.zone_id
}

output "arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.nomad.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.nomad.arn
}
