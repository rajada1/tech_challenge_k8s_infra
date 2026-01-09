variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "tech-challenge-cluster"
}

variable "node_instance_type" {
  description = "EKS Node Instance Type"
  type        = string
  default     = "t3.small"
}

variable "desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "newrelic_license_key" {
  description = "New Relic License Key (Ingest)"
  type        = string
  sensitive   = true
}

variable "newrelic_api_key" {
  description = "New Relic User API Key (for Terraform Provider)"
  type        = string
  sensitive   = true
}

variable "newrelic_account_id" {
  description = "New Relic Account ID"
  type        = string
}

variable "environment" {
  description = "Deployment Environment (e.g., homolog, prod)"
  type        = string
  default     = "homolog"
}

