resource "newrelic_one_dashboard" "tech_challenge_dashboard" {
  name        = "Tech Challenge - Oficina Monitoring"
  permissions = "public_read_write"

  page {
    name = "Overview"

    widget_billboard {
      title  = "Volume Diário de Ordens de Serviço"
      row    = 1
      column = 1
      width  = 4
      height = 3
      nrql_query {
        query = "SELECT count(*) FROM Transaction WHERE appName = 'Oficina Service - ${var.environment}' SINCE 1 day ago"
      }
    }

    widget_bar {
      title  = "Tempo Médio de Execução por Status"
      row    = 1
      column = 5
      width  = 4
      height = 3
      nrql_query {
        query = "SELECT average(duration) FROM Transaction WHERE appName = 'Oficina Service - ${var.environment}' FACET name"
      }
    }

    widget_pie {
      title  = "Erros e Falhas"
      row    = 1
      column = 9
      width  = 4
      height = 3
      nrql_query {
        query = "SELECT count(*) FROM TransactionError WHERE appName = 'Oficina Service - ${var.environment}' FACET error.message"
      }
    }

    widget_line {
      title  = "Latência de API (p95 e p99)"
      row    = 4
      column = 1
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT percentile(duration, 95, 99) FROM Transaction WHERE appName = 'Oficina Service - ${var.environment}' TIMESERIES"
      }
    }

    widget_area {
      title  = "K8s CPU Usage (Namespace Oficina)"
      row    = 4
      column = 7
      width  = 6
      height = 3
      nrql_query {
        query = "SELECT average(k8s.container.cpuCoresUtilization) FROM Metric WHERE namespaceName = 'oficina-${var.environment}' TIMESERIES"
      }
    }
  }
}
