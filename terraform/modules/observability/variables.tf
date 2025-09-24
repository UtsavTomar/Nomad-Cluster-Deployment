# Observability Module Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "nomad_server_log_group" {
  description = "Name of the Nomad server log group"
  type        = string
}

variable "nomad_client_log_group" {
  description = "Name of the Nomad client log group"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
