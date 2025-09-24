# Nomad Client Module Outputs

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.nomad_client.name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.nomad_client.id
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.nomad_client.name
}
