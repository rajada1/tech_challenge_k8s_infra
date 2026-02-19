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

variable "use_minikube" {
  description = "If true, provision a single EC2 instance for Docker/Minikube instead of EKS"
  type        = bool
  default     = true
}

variable "minikube_instance_type" {
  description = "EC2 instance type for Minikube"
  type        = string
  default     = "t3.micro"
}

variable "minikube_key_name" {
  description = "Optional EC2 KeyPair name to allow SSH into the Minikube instance"
  type        = string
  default     = ""
}

variable "newrelic_license_key" {
  description = "New Relic License Key (Ingest)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.newrelic_license_key) > 0
    error_message = "The New Relic License Key must not be empty. Please set the NEW_RELIC_LICENSE_KEY secret in GitHub."
  }
}

variable "newrelic_api_key" {
  description = "New Relic User API Key (for Terraform Provider)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.newrelic_api_key) > 0
    error_message = "The New Relic User API Key must not be empty. Please set the NEW_RELIC_API_KEY secret in GitHub."
  }
}

variable "newrelic_account_id" {
  description = "New Relic Account ID"
  type        = string
  default     = ""

  validation {
    condition     = length(var.newrelic_account_id) > 0
    error_message = "The New Relic Account ID must not be empty. Please set the NEW_RELIC_ACCOUNT_ID secret in GitHub."
  }
}

variable "environment" {
  description = "Deployment Environment (e.g., homolog, prod)"
  type        = string
  default     = "homolog"
}

