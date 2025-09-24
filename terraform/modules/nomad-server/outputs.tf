# Nomad Server Module Outputs

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.nomad_server.name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.nomad_server.id
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.nomad_server.name
}

output "private_ips" {
  description = "Private IPs of the Nomad servers"
  value       = data.aws_instances.nomad_servers.private_ips
}

output "instance_ids" {
  description = "Instance IDs of the Nomad servers"
  value       = data.aws_instances.nomad_servers.ids
}