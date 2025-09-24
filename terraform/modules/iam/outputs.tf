# IAM Module Outputs

output "nomad_server_role_name" {
  description = "Name of the Nomad server IAM role"
  value       = aws_iam_role.nomad_server.name
}

output "nomad_client_role_name" {
  description = "Name of the Nomad client IAM role"
  value       = aws_iam_role.nomad_client.name
}

output "nomad_server_instance_profile_name" {
  description = "Name of the Nomad server instance profile"
  value       = aws_iam_instance_profile.nomad_server.name
}

output "nomad_client_instance_profile_name" {
  description = "Name of the Nomad client instance profile"
  value       = aws_iam_instance_profile.nomad_client.name
}
