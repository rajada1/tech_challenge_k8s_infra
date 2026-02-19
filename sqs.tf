# ==========================================
# AWS SQS FIFO Queues - Saga Pattern
# ==========================================
# Event-driven architecture using SQS FIFO
# with idempotency and dead letter queues

# ==========================================
# Variables
# ==========================================

locals {
  services = {
    customer = {
      queue_name  = "customer-events"
      description = "Customer Service - Client creation events"
    }
    people = {
      queue_name  = "people-events"
      description = "People Service - Person management events"
    }
    hr = {
      queue_name  = "hr-events"
      description = "HR Service - Human resources events"
    }
    catalog = {
      queue_name  = "catalog-events"
      description = "Catalog Service - Product catalog events"
    }
    billing = {
      queue_name  = "billing-events"
      description = "Billing Service - Billing and payment events"
    }
    execution = {
      queue_name  = "execution-events"
      description = "Execution Service - Service execution events"
    }
    os = {
      queue_name  = "os-events"
      description = "OS Service (Oficina) - Service order events"
    }
    maintenance = {
      queue_name  = "maintenance-events"
      description = "Maintenance Service - Maintenance events"
    }
    notification = {
      queue_name  = "notification-events"
      description = "Notification Service - Notification events"
    }
    operations = {
      queue_name  = "operations-events"
      description = "Operations Service - Operations events"
    }
  }

  queue_config = {
    visibility_timeout_seconds  = 60     # 60 seconds for processing
    message_retention_seconds   = 345600 # 4 days in seconds
    content_based_deduplication = false  # Use messageDeduplicationId
    # Use perQueue to avoid DeduplicationScope API constraint in some accounts/regions
    fifo_throughput_limit = "perQueue"
    kms_master_key_id     = null # Use default AWS managed key
  }

  dlq_config = {
    max_receive_count = 3 # Move to DLQ after 3 failed attempts
  }
}

# ==========================================
# Dead Letter Queues (DLQ) - FIFO
# ==========================================

resource "aws_sqs_queue" "dlq_fifo" {
  for_each = local.services

  name                        = "${each.value.queue_name}-dlq.fifo"
  fifo_queue                  = true
  content_based_deduplication = local.queue_config.content_based_deduplication
  deduplication_scope         = "messageGroup"
  visibility_timeout_seconds  = local.queue_config.visibility_timeout_seconds
  message_retention_seconds   = local.queue_config.message_retention_seconds
  fifo_throughput_limit       = local.queue_config.fifo_throughput_limit

  tags = {
    Name        = "${each.value.queue_name}-dlq"
    Service     = each.key
    Environment = var.environment
    Purpose     = "Dead Letter Queue for failed saga events"
    ManagedBy   = "Terraform"
  }
}

# ==========================================
# Main Event Queues (FIFO)
# ==========================================

resource "aws_sqs_queue" "service_events_fifo" {
  for_each = local.services

  name                        = "${each.value.queue_name}.fifo"
  fifo_queue                  = true
  content_based_deduplication = local.queue_config.content_based_deduplication
  deduplication_scope         = "messageGroup"
  visibility_timeout_seconds  = local.queue_config.visibility_timeout_seconds
  message_retention_seconds   = local.queue_config.message_retention_seconds
  fifo_throughput_limit       = local.queue_config.fifo_throughput_limit

  # Redrive Policy - Link to DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq_fifo[each.key].arn
    maxReceiveCount     = local.dlq_config.max_receive_count
  })

  tags = {
    Name        = each.value.queue_name
    Service     = each.key
    Environment = var.environment
    Pattern     = "Saga Event-Driven"
    # sanitize description to remove characters not allowed in SQS tag values (e.g. parentheses)
    Description = replace(replace(each.value.description, "(", ""), ")", "")
    ManagedBy   = "Terraform"
  }
}

# ==========================================
# Queue Policies - Allow EKS Pod to Access
# ==========================================

resource "aws_sqs_queue_policy" "service_events_policy" {
  for_each = local.services

  queue_url = aws_sqs_queue.service_events_fifo[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.eks_pod_role[each.key].name}"
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
          "sqs:PurgeQueue"
        ]
        Resource = aws_sqs_queue.service_events_fifo[each.key].arn
      }
    ]
  })
}

# ==========================================
# Data Sources
# ==========================================

data "aws_caller_identity" "current" {}

# ==========================================
# Outputs
# ==========================================

output "sqs_queue_urls" {
  description = "SQS Queue URLs for all services"
  value = {
    for service, queue in aws_sqs_queue.service_events_fifo :
    service => queue.url
  }
}

output "sqs_queue_arns" {
  description = "SQS Queue ARNs for all services"
  value = {
    for service, queue in aws_sqs_queue.service_events_fifo :
    service => queue.arn
  }
}

output "sqs_dlq_urls" {
  description = "SQS DLQ URLs for all services"
  value = {
    for service, queue in aws_sqs_queue.dlq_fifo :
    service => queue.url
  }
}

output "sqs_dlq_arns" {
  description = "SQS DLQ ARNs for all services"
  value = {
    for service, queue in aws_sqs_queue.dlq_fifo :
    service => queue.arn
  }
}
