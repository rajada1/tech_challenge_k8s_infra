# ==========================================
# IAM Roles for SQS Access
# ==========================================
# IRSA (IAM Roles for Service Accounts)
# Allows EKS pods to assume roles with SQS permissions

# ==========================================
# Create IAM Roles for Each Service
# ==========================================

resource "aws_iam_role" "eks_pod_role" {
  # only create IRSA roles when EKS is enabled (not using Minikube)
  for_each = var.use_minikube ? {} : local.services

  # use name_prefix to avoid conflicts with existing roles in the account
  name_prefix = "${each.key}-service-sqs-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = try(module.eks[0].oidc_provider_arn, "")
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${try(module.eks[0].oidc_provider, "")}:sub" = "system:serviceaccount:${each.key}:${each.key}-sa"
            # note: using try() to avoid invalid attribute access when EKS module is not created
            "${try(module.eks[0].oidc_provider, "")}:aud" = "sts.amazonaws.com"
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
  for_each = var.use_minikube ? {} : local.services

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
