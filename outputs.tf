output "cluster_endpoint" {
  description = "Endpoint for EKS control plane (empty when using Minikube)"
  value       = var.use_minikube ? "" : module.eks[0].cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane (empty when using Minikube)"
  value       = var.use_minikube ? "" : module.eks[0].cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name (empty when using Minikube)"
  value       = var.use_minikube ? "" : module.eks[0].cluster_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = join(",", module.vpc.private_subnets)
}
