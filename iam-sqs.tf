# ==========================================
# IAM Roles for SQS Access
# ==========================================
# IRSA (IAM Roles for Service Accounts)
# Allows EKS pods to assume roles with SQS permissions

# ==========================================
# Create IAM Roles for Each Service
# ==========================================

resource "aws_iam_role" "eks_pod_role" {
  for_each = local.services

  name = "${each.key}-service-sqs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${each.key}:${each.key}-sa"
            "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${each.key}-service-sqs-role"
    Service     = each.key
    Environment = var.environment
    Purpose     = "IRSA for SQS access"
    ManagedBy   = "Terraform"
  }
}

# ==========================================
# IAM Policies for SQS Permissions
# ==========================================

resource "aws_iam_role_policy" "eks_sqs_policy" {
  for_each = local.services

  name = "${each.key}-sqs-policy"
  role = aws_iam_role.eks_pod_role[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SendMessages"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:SendMessageBatch"
        ]
        Resource = aws_sqs_queue.service_events_fifo[each.key].arn
      },
      {
        Sid    = "ReceiveMessages"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:DeleteMessageBatch",
          "sqs:ChangeMessageVisibility",
          "sqs:ChangeMessageVisibilityBatch",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.service_events_fifo[each.key].arn
      },
      {
        Sid    = "DLQAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.dlq_fifo[each.key].arn
      },
      {
        Sid    = "ListQueues"
        Effect = "Allow"
        Action = [
          "sqs:ListQueues"
        ]
        Resource = "*"
      }
    ]
  })
}

# ==========================================
# Data Sources
# ==========================================

data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

# ==========================================
# Outputs
# ==========================================

output "service_account_roles" {
  description = "IAM roles for service accounts"
  value = {
    for service, role in aws_iam_role.eks_pod_role :
    service => {
      role_arn  = role.arn
      role_name = role.name
    }
  }
}
