provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# 1. Create the Namespace for the Application and Monitoring tools
resource "kubernetes_namespace" "oficina" {
  metadata {
    name = "oficina-${var.environment}"
    labels = {
      name = "oficina"
      env  = var.environment
    }
  }
}

# 2. Deploy New Relic Bundle (Infrastructure Monitoring, Logging, etc.)
resource "helm_release" "newrelic_bundle" {
  name       = "newrelic-bundle"
  namespace  = kubernetes_namespace.oficina.metadata[0].name
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"
  version    = "5.0.0" # Clean version pinning

  set {
    name  = "global.licenseKey"
    value = var.newrelic_license_key
  }

  set {
    name  = "global.cluster"
    value = module.eks.cluster_name
  }

  set {
    name  = "newrelic-infrastructure.privileged"
    value = "true"
  }

  set {
    name  = "ksm.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  set {
    name  = "kubeEvents.enabled"
    value = "true"
  }

  set {
    name  = "logging.enabled"
    value = "true"
  }

  # Ensure bundle doesn't conflict if re-deployed in same cluster but different ns
  # Though NR Bundle is usually cluster-wide for Infra Agent. 
  # If multiple envs share cluster, Infra Agent should be DaemonSet (1 per node).
  # We might need to be careful here if deploying multiple times.
  # For this challenge, assuming 1 env active or separate clusters.
}

# 3. Create the Secret for the Application (APM)
resource "kubernetes_secret" "newrelic_secret" {
  metadata {
    name      = "newrelic-secret"
    namespace = kubernetes_namespace.oficina.metadata[0].name
  }

  data = {
    license-key = var.newrelic_license_key
  }

  type = "Opaque"
}

# 4. Create the ConfigMap for the Application (APM)
resource "kubernetes_config_map" "newrelic_config" {
  metadata {
    name      = "newrelic-config"
    namespace = kubernetes_namespace.oficina.metadata[0].name
  }

  data = {
    NEW_RELIC_ENVIRONMENT                 = var.environment
    NEW_RELIC_DISTRIBUTED_TRACING_ENABLED = "true"
    NEW_RELIC_LOG_LEVEL                   = "info"
  }
}
