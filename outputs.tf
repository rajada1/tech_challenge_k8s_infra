output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = module.eks.cluster_version
}

# ==============================================================================
# NEW RELIC MONITORING OUTPUTS
# ==============================================================================

output "newrelic_alert_policy_id" {
  description = "New Relic Alert Policy ID for EKS infrastructure"
  value       = var.enable_newrelic_monitoring ? newrelic_alert_policy.eks_infrastructure[0].id : null
}

output "newrelic_dashboard_url" {
  description = "URL to access the New Relic Dashboard"
  value       = var.enable_newrelic_monitoring ? "https://one.newrelic.com/dashboards/${newrelic_one_dashboard.eks_infrastructure[0].guid}" : null
}

output "newrelic_integration_installed" {
  description = "Whether New Relic Kubernetes integration is installed"
  value       = var.enable_newrelic_monitoring
}

output "newrelic_namespace" {
  description = "Kubernetes namespace where New Relic is deployed"
  value       = var.enable_newrelic_monitoring ? "newrelic" : null
}

# ==============================================================================
# VPC OUTPUTS
# ==============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}
