module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  create_kms_key            = false
  cluster_encryption_config = {}
  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  cluster_endpoint_public_access  = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    instance_types = [var.node_instance_type]
  }

  eks_managed_node_groups = {
    default_node_group = {
      min_size     = 1
      max_size     = 3
      desired_size = var.desired_capacity

      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
