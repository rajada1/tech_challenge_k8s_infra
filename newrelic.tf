# ==============================================================================
# NEW RELIC OBSERVABILITY FOR EKS CLUSTER
# ==============================================================================
# This file contains the complete New Relic observability infrastructure for
# the EKS cluster, including:
# - Kubernetes Integration via Helm
# - Infrastructure monitoring
# - Alert policies and conditions
# - Custom dashboards
# - Notification workflows
# ==============================================================================

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "aws_caller_identity" "current" {}

# ==============================================================================
# NEW RELIC KUBERNETES INTEGRATION
# ==============================================================================

# New Relic Infrastructure - Kubernetes Integration
# Deploys the New Relic Kubernetes integration via Helm chart
resource "helm_release" "newrelic_bundle" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  name       = "newrelic-bundle"
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"
  version    = "~> 5.0"
  namespace  = "newrelic"

  create_namespace = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      global = {
        licenseKey = var.newrelic_license_key
        cluster    = var.cluster_name
      }

      # New Relic Infrastructure Agent
      newrelic-infrastructure = {
        enabled = true
        privileged = true
        config = {
          interval = 15
        }
      }

      # Kubernetes Events Integration
      nri-kube-events = {
        enabled = true
      }

      # Metrics Adapter (for HPA with custom metrics)
      nri-metadata-injection = {
        enabled = true
      }

      # Prometheus Integration
      nri-prometheus = {
        enabled = true
        config = {
          transformations = [
            {
              description = "General Kubernetes Metrics"
              add_attributes = [
                {
                  metric_prefix = ""
                  attributes = {
                    cluster_name = var.cluster_name
                    environment  = var.environment
                  }
                }
              ]
            }
          ]
        }
      }

      # Kubernetes State Metrics
      kube-state-metrics = {
        enabled = true
      }

      # Pixie for eBPF-based observability
      pixie = {
        enabled = false  # Can be enabled for advanced tracing
      }

      # Logs Integration
      newrelic-logging = {
        enabled = var.enable_logging
        fluentBit = {
          criEnabled = true
        }
      }
    })
  ]

  depends_on = [module.eks]
}

# ==============================================================================
# ALERT POLICY - EKS CLUSTER
# ==============================================================================

resource "newrelic_alert_policy" "eks_infrastructure" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  name                = "Tech Challenge - EKS Infrastructure"
  incident_preference = "PER_CONDITION"
}

# ==============================================================================
# ALERT CONDITIONS - CLUSTER HEALTH
# ==============================================================================

# Alert: High Node CPU Usage
resource "newrelic_nrql_alert_condition" "high_node_cpu" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  account_id                     = var.newrelic_account_id
  policy_id                      = newrelic_alert_policy.eks_infrastructure[0].id
  type                           = "static"
  name                           = "High Node CPU Usage"
  description                    = "Alert when node CPU usage exceeds threshold"
  enabled                        = true
  violation_time_limit_seconds   = 259200  # 3 days
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  slide_by                       = 30

  nrql {
    query = "FROM K8sNodeSample SELECT average(cpuUsedCores / cpuLimitCores) * 100 WHERE clusterName = '${var.cluster_name}' FACET nodeName"
  }

  critical {
    operator              = "above"
    threshold             = var.alert_node_cpu_threshold
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = var.alert_node_cpu_threshold * 0.8
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

# Alert: High Node Memory Usage
resource "newrelic_nrql_alert_condition" "high_node_memory" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  account_id                     = var.newrelic_account_id
  policy_id                      = newrelic_alert_policy.eks_infrastructure[0].id
  type                           = "static"
  name                           = "High Node Memory Usage"
  description                    = "Alert when node memory usage exceeds threshold"
  enabled                        = true
  violation_time_limit_seconds   = 259200
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  slide_by                       = 30

  nrql {
    query = "FROM K8sNodeSample SELECT average(memoryUsedBytes / memoryLimitBytes) * 100 WHERE clusterName = '${var.cluster_name}' FACET nodeName"
  }

  critical {
    operator              = "above"
    threshold             = var.alert_node_memory_threshold
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = var.alert_node_memory_threshold * 0.8
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

# Alert: Node Not Ready
resource "newrelic_nrql_alert_condition" "node_not_ready" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  account_id                     = var.newrelic_account_id
  policy_id                      = newrelic_alert_policy.eks_infrastructure[0].id
  type                           = "static"
  name                           = "Node Not Ready"
  description                    = "Alert when a node is not in ready state"
  enabled                        = true
  violation_time_limit_seconds   = 259200
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  slide_by                       = 30

  nrql {
    query = "FROM K8sNodeSample SELECT latest(condition.Ready) WHERE clusterName = '${var.cluster_name}' FACET nodeName"
  }

  critical {
    operator              = "below"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

# Alert: High Pod CPU Usage
resource "newrelic_nrql_alert_condition" "high_pod_cpu" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  account_id                     = var.newrelic_account_id
  policy_id                      = newrelic_alert_policy.eks_infrastructure[0].id
  type                           = "static"
  name                           = "High Pod CPU Usage"
  description                    = "Alert when pod CPU usage exceeds threshold"
  enabled                        = true
  violation_time_limit_seconds   = 259200
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  slide_by                       = 30

  nrql {
    query = "FROM K8sPodSample SELECT average(cpuUsedCores / cpuLimitCores) * 100 WHERE clusterName = '${var.cluster_name}' AND namespaceName NOT IN ('kube-system', 'newrelic') FACET podName, namespaceName"
  }

  critical {
    operator              = "above"
    threshold             = var.alert_pod_cpu_threshold
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = var.alert_pod_cpu_threshold * 0.8
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

# Alert: High Pod Memory Usage
resource "newrelic_nrql_alert_condition" "high_pod_memory" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  account_id                     = var.newrelic_account_id
  policy_id                      = newrelic_alert_policy.eks_infrastructure[0].id
  type                           = "static"
  name                           = "High Pod Memory Usage"
  description                    = "Alert when pod memory usage exceeds threshold"
  enabled                        = true
  violation_time_limit_seconds   = 259200
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  slide_by                       = 30

  nrql {
    query = "FROM K8sPodSample SELECT average(memoryUsedBytes / memoryLimitBytes) * 100 WHERE clusterName = '${var.cluster_name}' AND namespaceName NOT IN ('kube-system', 'newrelic') FACET podName, namespaceName"
  }

  critical {
    operator              = "above"
    threshold             = var.alert_pod_memory_threshold
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = var.alert_pod_memory_threshold * 0.8
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

# Alert: Pod Restart Loop
resource "newrelic_nrql_alert_condition" "pod_restart_loop" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  account_id                     = var.newrelic_account_id
  policy_id                      = newrelic_alert_policy.eks_infrastructure[0].id
  type                           = "static"
  name                           = "Pod Restart Loop"
  description                    = "Alert when a pod is restarting frequently"
  enabled                        = true
  violation_time_limit_seconds   = 259200
  aggregation_window             = 300  # 5 minutes
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  slide_by                       = 60

  nrql {
    query = "FROM K8sContainerSample SELECT sum(restartCount) WHERE clusterName = '${var.cluster_name}' FACET podName, namespaceName"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 3
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

# Alert: High Container CPU Throttling
resource "newrelic_nrql_alert_condition" "high_cpu_throttling" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  account_id                     = var.newrelic_account_id
  policy_id                      = newrelic_alert_policy.eks_infrastructure[0].id
  type                           = "static"
  name                           = "High CPU Throttling"
  description                    = "Alert when containers experience high CPU throttling"
  enabled                        = true
  violation_time_limit_seconds   = 259200
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  slide_by                       = 30

  nrql {
    query = "FROM K8sContainerSample SELECT average(cpuThrottledTimePercent) WHERE clusterName = '${var.cluster_name}' FACET containerName, podName, namespaceName"
  }

  critical {
    operator              = "above"
    threshold             = 50  # 50% throttling
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 30
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

# Alert: Deployment Replica Mismatch
resource "newrelic_nrql_alert_condition" "deployment_replica_mismatch" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  account_id                     = var.newrelic_account_id
  policy_id                      = newrelic_alert_policy.eks_infrastructure[0].id
  type                           = "static"
  name                           = "Deployment Replica Mismatch"
  description                    = "Alert when deployment has fewer ready replicas than desired"
  enabled                        = true
  violation_time_limit_seconds   = 259200
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  slide_by                       = 30

  nrql {
    query = "FROM K8sDeploymentSample SELECT latest(podsDesired - podsReady) WHERE clusterName = '${var.cluster_name}' FACET deploymentName, namespaceName"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 600  # 10 minutes
    threshold_occurrences = "all"
  }
}

# ==============================================================================
# DASHBOARD - EKS CLUSTER OVERVIEW
# ==============================================================================

resource "newrelic_one_dashboard" "eks_infrastructure" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  name        = "Tech Challenge - EKS Cluster"
  permissions = "public_read_write"

  # ==============================================================================
  # PAGE 1: CLUSTER OVERVIEW
  # ==============================================================================
  
  page {
    name = "Cluster Overview"

    # Widget: Cluster Status
    widget_billboard {
      title  = "Cluster Status"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sClusterSample SELECT latest(clusterName) as 'Cluster', uniqueCount(nodeName) as 'Nodes', sum(allocatableCpuCores) as 'Total CPUs', sum(allocatableMemoryBytes) / 1073741824 as 'Total Memory (GB)' WHERE clusterName = '${var.cluster_name}'"
      }
    }

    # Widget: Node CPU Usage
    widget_line {
      title  = "Node CPU Usage (%)"
      row    = 1
      column = 5
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sNodeSample SELECT average(cpuUsedCores / cpuLimitCores) * 100 WHERE clusterName = '${var.cluster_name}' FACET nodeName TIMESERIES AUTO"
      }
    }

    # Widget: Node Memory Usage
    widget_line {
      title  = "Node Memory Usage (%)"
      row    = 1
      column = 9
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sNodeSample SELECT average(memoryUsedBytes / memoryLimitBytes) * 100 WHERE clusterName = '${var.cluster_name}' FACET nodeName TIMESERIES AUTO"
      }
    }

    # Widget: Pod Count by Namespace
    widget_bar {
      title  = "Pod Count by Namespace"
      row    = 4
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPodSample SELECT uniqueCount(podName) WHERE clusterName = '${var.cluster_name}' FACET namespaceName"
      }
    }

    # Widget: Pod Status Distribution
    widget_pie {
      title  = "Pod Status Distribution"
      row    = 4
      column = 5
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPodSample SELECT count(*) WHERE clusterName = '${var.cluster_name}' FACET status"
      }
    }

    # Widget: Container Restart Count
    widget_line {
      title  = "Container Restarts (Last Hour)"
      row    = 4
      column = 9
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sContainerSample SELECT sum(restartCount) WHERE clusterName = '${var.cluster_name}' FACET podName TIMESERIES AUTO SINCE 1 hour ago"
      }
    }

    # Widget: Network RX
    widget_area {
      title  = "Network Received (bytes/sec)"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPodSample SELECT average(net.rxBytesPerSecond) WHERE clusterName = '${var.cluster_name}' FACET podName TIMESERIES AUTO LIMIT 10"
      }
    }

    # Widget: Network TX
    widget_area {
      title  = "Network Transmitted (bytes/sec)"
      row    = 7
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPodSample SELECT average(net.txBytesPerSecond) WHERE clusterName = '${var.cluster_name}' FACET podName TIMESERIES AUTO LIMIT 10"
      }
    }
  }

  # ==============================================================================
  # PAGE 2: POD & CONTAINER METRICS
  # ==============================================================================
  
  page {
    name = "Pods & Containers"

    # Widget: Top CPU Consuming Pods
    widget_table {
      title  = "Top CPU Consuming Pods"
      row    = 1
      column = 1
      width  = 6
      height = 4

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPodSample SELECT latest(podName) as 'Pod', latest(namespaceName) as 'Namespace', average(cpuUsedCores) as 'CPU Cores', average(cpuUsedCores / cpuLimitCores) * 100 as 'CPU %' WHERE clusterName = '${var.cluster_name}' FACET podName, namespaceName LIMIT 20"
      }
    }

    # Widget: Top Memory Consuming Pods
    widget_table {
      title  = "Top Memory Consuming Pods"
      row    = 1
      column = 7
      width  = 6
      height = 4

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPodSample SELECT latest(podName) as 'Pod', latest(namespaceName) as 'Namespace', average(memoryUsedBytes) / 1048576 as 'Memory (MB)', average(memoryUsedBytes / memoryLimitBytes) * 100 as 'Memory %' WHERE clusterName = '${var.cluster_name}' FACET podName, namespaceName LIMIT 20"
      }
    }

    # Widget: Container CPU Usage by Namespace
    widget_area {
      title  = "Container CPU Usage by Namespace"
      row    = 5
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sContainerSample SELECT average(cpuUsedCores) WHERE clusterName = '${var.cluster_name}' FACET namespaceName TIMESERIES AUTO"
      }
    }

    # Widget: Container Memory Usage by Namespace
    widget_area {
      title  = "Container Memory Usage by Namespace (MB)"
      row    = 5
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sContainerSample SELECT average(memoryUsedBytes) / 1048576 WHERE clusterName = '${var.cluster_name}' FACET namespaceName TIMESERIES AUTO"
      }
    }

    # Widget: CPU Throttling
    widget_line {
      title  = "CPU Throttling (%)"
      row    = 8
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sContainerSample SELECT average(cpuThrottledTimePercent) WHERE clusterName = '${var.cluster_name}' FACET containerName TIMESERIES AUTO LIMIT 10"
      }
    }

    # Widget: File System Usage
    widget_line {
      title  = "Pod Filesystem Usage (%)"
      row    = 8
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPodSample SELECT average(fsUsedPercent) WHERE clusterName = '${var.cluster_name}' AND fsUsedPercent IS NOT NULL FACET podName TIMESERIES AUTO LIMIT 10"
      }
    }
  }

  # ==============================================================================
  # PAGE 3: DEPLOYMENTS & SERVICES
  # ==============================================================================
  
  page {
    name = "Deployments & Services"

    # Widget: Deployment Status
    widget_table {
      title  = "Deployment Status"
      row    = 1
      column = 1
      width  = 6
      height = 4

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sDeploymentSample SELECT latest(deploymentName) as 'Deployment', latest(namespaceName) as 'Namespace', latest(podsDesired) as 'Desired', latest(podsReady) as 'Ready', latest(podsAvailable) as 'Available' WHERE clusterName = '${var.cluster_name}' FACET deploymentName, namespaceName"
      }
    }

    # Widget: Replica Availability
    widget_line {
      title  = "Replica Availability Over Time"
      row    = 1
      column = 7
      width  = 6
      height = 4

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sDeploymentSample SELECT average(podsReady / podsDesired) * 100 WHERE clusterName = '${var.cluster_name}' FACET deploymentName TIMESERIES AUTO"
      }
    }

    # Widget: Service Count
    widget_billboard {
      title  = "Services"
      row    = 5
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sServiceSample SELECT uniqueCount(serviceName) as 'Total Services' WHERE clusterName = '${var.cluster_name}'"
      }
    }

    # Widget: Events Summary
    widget_table {
      title  = "Recent Kubernetes Events"
      row    = 5
      column = 5
      width  = 8
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM InfrastructureEvent SELECT timestamp, event.reason, event.message WHERE clusterName = '${var.cluster_name}' AND category = 'kubernetes' LIMIT 50"
      }
    }

    # Widget: HPA Status
    widget_table {
      title  = "Horizontal Pod Autoscaler Status"
      row    = 8
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sHpaSample SELECT latest(hpaName) as 'HPA', latest(namespaceName) as 'Namespace', latest(currentReplicas) as 'Current', latest(desiredReplicas) as 'Desired', latest(maxReplicas) as 'Max' WHERE clusterName = '${var.cluster_name}' FACET hpaName, namespaceName"
      }
    }
  }

  # ==============================================================================
  # PAGE 4: PERSISTENT VOLUMES
  # ==============================================================================
  
  page {
    name = "Storage"

    # Widget: PV Status
    widget_table {
      title  = "Persistent Volume Status"
      row    = 1
      column = 1
      width  = 6
      height = 4

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPersistentVolumeSample SELECT latest(volumeName) as 'Volume', latest(phase) as 'Phase', latest(capacityBytes) / 1073741824 as 'Capacity (GB)' WHERE clusterName = '${var.cluster_name}' FACET volumeName"
      }
    }

    # Widget: PVC Status
    widget_table {
      title  = "Persistent Volume Claim Status"
      row    = 1
      column = 7
      width  = 6
      height = 4

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPersistentVolumeClaimSample SELECT latest(pvcName) as 'PVC', latest(namespaceName) as 'Namespace', latest(phase) as 'Phase', latest(requestedStorageBytes) / 1073741824 as 'Size (GB)' WHERE clusterName = '${var.cluster_name}' FACET pvcName, namespaceName"
      }
    }

    # Widget: Storage Class Distribution
    widget_pie {
      title  = "Storage Class Distribution"
      row    = 5
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPersistentVolumeSample SELECT count(*) WHERE clusterName = '${var.cluster_name}' FACET storageClass"
      }
    }

    # Widget: Volume Usage
    widget_line {
      title  = "Volume Usage Over Time (GB)"
      row    = 5
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sPersistentVolumeSample SELECT sum(capacityBytes) / 1073741824 WHERE clusterName = '${var.cluster_name}' TIMESERIES AUTO"
      }
    }
  }
}

# ==============================================================================
# NOTIFICATION CHANNEL - EMAIL
# ==============================================================================

resource "newrelic_notification_destination" "email" {
  count = var.enable_newrelic_monitoring && var.alert_email != "" ? 1 : 0

  account_id = var.newrelic_account_id
  name       = "Tech Challenge - EKS Email"
  type       = "EMAIL"

  property {
    key   = "email"
    value = var.alert_email
  }
}

resource "newrelic_notification_channel" "email" {
  count = var.enable_newrelic_monitoring && var.alert_email != "" ? 1 : 0

  account_id     = var.newrelic_account_id
  name           = "Tech Challenge - EKS Email Channel"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email[0].id
  product        = "IINT"

  property {
    key   = "subject"
    value = "Tech Challenge EKS Alert: {{ issueTitle }}"
  }
}

# ==============================================================================
# NOTIFICATION WORKFLOW
# ==============================================================================

resource "newrelic_workflow" "email_notifications" {
  count = var.enable_newrelic_monitoring && var.alert_email != "" ? 1 : 0

  name                  = "Tech Challenge - EKS Email Notifications"
  account_id            = var.newrelic_account_id
  muting_rules_handling = "NOTIFY_ALL_ISSUES"
  enabled               = true

  issues_filter {
    name = "Filter by Policy"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.eks_infrastructure[0].id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email[0].id
  }
}
