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

# ==============================================================================
# NEW RELIC CONFIGURATION VARIABLES
# ==============================================================================

variable "enable_newrelic_monitoring" {
  description = "Enable New Relic monitoring and observability for EKS cluster"
  type        = bool
  default     = true
}

variable "newrelic_account_id" {
  description = "New Relic Account ID"
  type        = string
  sensitive   = true
}

variable "newrelic_api_key" {
  description = "New Relic API Key (User Key for API access)"
  type        = string
  sensitive   = true
}

variable "newrelic_license_key" {
  description = "New Relic License Key (for agent installation)"
  type        = string
  sensitive   = true
}

variable "newrelic_region" {
  description = "New Relic Region (US or EU)"
  type        = string
  default     = "US"
  validation {
    condition     = contains(["US", "EU"], var.newrelic_region)
    error_message = "New Relic region must be either US or EU."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# ==============================================================================
# LOGGING CONFIGURATION
# ==============================================================================

variable "enable_logging" {
  description = "Enable New Relic logging integration"
  type        = bool
  default     = true
}

# ==============================================================================
# ALERT THRESHOLD VARIABLES
# ==============================================================================

variable "alert_node_cpu_threshold" {
  description = "Node CPU utilization threshold for critical alert (%)"
  type        = number
  default     = 80
}

variable "alert_node_memory_threshold" {
  description = "Node memory utilization threshold for critical alert (%)"
  type        = number
  default     = 80
}

variable "alert_pod_cpu_threshold" {
  description = "Pod CPU utilization threshold for critical alert (%)"
  type        = number
  default     = 90
}

variable "alert_pod_memory_threshold" {
  description = "Pod memory utilization threshold for critical alert (%)"
  type        = number
  default     = 90
}

variable "alert_email" {
  description = "Email address for alert notifications (leave empty to disable email alerts)"
  type        = string
  default     = ""
}
