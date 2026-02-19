module "eks" {
  count                     = var.use_minikube ? 0 : 1
  source                    = "terraform-aws-modules/eks/aws"
  version                   = "~> 19.0"
  create_kms_key            = false
  cluster_encryption_config = {}
  cluster_name              = var.cluster_name
  cluster_version           = "1.29"

  cluster_endpoint_public_access = true

  # NOTE: role mapping and OIDC provider resources moved below module
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



# OIDC provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM role for GitHub Actions to assume (limited to this repository)
resource "aws_iam_role" "github_actions_deployer" {
  name = "github-actions-deployer-${data.aws_caller_identity.current.account_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # restrict to this repository (allow any ref)
            "token.actions.githubusercontent.com:sub" = "repo:rajada1/oficina-catalog-service:*"
          }
        }
      }
    ]
  })
}

# Minimal inline policy to allow EKS describe for update-kubeconfig
resource "aws_iam_role_policy" "github_actions_deployer_policy" {
  name = "github-actions-deployer-policy"
  role = aws_iam_role.github_actions_deployer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "sts:GetCallerIdentity",
          # ECR permissions for pushing images from GitHub Actions
          "ecr:GetAuthorizationToken",
          "ecr:DescribeRepositories",
          "ecr:CreateRepository",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      }
    ]
  })
}

# To map the created role into the cluster aws-auth, either use the EKS module
# input `map_roles` if supported by the module version, or manually patch the
# `aws-auth` ConfigMap after applying these resources. For now the module
# mapping was removed to keep `terraform validate` happy; apply the mapping
# after confirming module supports it or via a separate resource.
