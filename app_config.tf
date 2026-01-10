resource "kubernetes_config_map" "oficina_config" {
  metadata {
    name      = "oficina-config"
    namespace = kubernetes_namespace.oficina.metadata[0].name
  }

  data = {
    DB_HOST                                   = "postgres"
    DB_PORT                                   = "5432"
    DB_NAME                                   = "oficina_db"
    MAIL_HOST                                 = "smtp.mailtrap.io"
    MAIL_PORT                                 = "2525"
    JPA_DDL_AUTO                              = "update"
    SHOW_SQL                                  = "true"
    SECURITY_DISABLED                         = "true"
    MANAGEMENT_HEALTH_MAIL_ENABLED            = "false"
    MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS   = "always"
    MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE = "health,info,metrics,prometheus,env,loggers"
    MANAGEMENT_HEALTH_DB_ENABLED              = "true"
    MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED = "true"
    MANAGEMENT_HEALTH_LIVENESSSTATE_ENABLED   = "true"
    MANAGEMENT_HEALTH_READINESSSTATE_ENABLED  = "true"

    # New Relic Configuration
    NEW_RELIC_ENVIRONMENT                 = var.environment
    NEW_RELIC_DISTRIBUTED_TRACING_ENABLED = "true"
    NEW_RELIC_LOG_LEVEL                   = "info"
    ENVIRONMENT                           = var.environment
  }
}
