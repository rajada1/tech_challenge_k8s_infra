# New Relic Kubernetes Infrastructure - Documentação Técnica

> Documentação completa da implementação de observabilidade New Relic para EKS

[![New Relic](https://img.shields.io/badge/New_Relic-v3.0-00AC69?logo=new-relic)](https://newrelic.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-v5.0-0F1689?logo=helm)](https://helm.sh/)

---

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura](#arquitetura)
3. [Componentes](#componentes)
4. [Helm Integration](#helm-integration)
5. [Métricas Coletadas](#métricas-coletadas)
6. [Alertas](#alertas)
7. [Dashboard](#dashboard)
8. [Troubleshooting](#troubleshooting)
9. [Performance Impact](#performance-impact)
10. [Custos](#custos)

---

## Visão Geral

Esta implementação fornece observabilidade completa para clusters EKS usando a integração Kubernetes da New Relic via Helm. A solução é **production-ready** e segue as melhores práticas de observabilidade.

### Componentes Principais

```
┌──────────────────────────────────────────────────────────────┐
│                    NEW RELIC BUNDLE (nri-bundle)              │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Infrastructure Agent (DaemonSet)                   │    │
│  │  - Coleta métricas de nodes                         │    │
│  │  - Envia para New Relic One                         │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Kube-State-Metrics (Deployment)                    │    │
│  │  - Métricas de objetos Kubernetes                   │    │
│  │  - Deployments, StatefulSets, Pods, etc.           │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Kubernetes Events (Deployment)                     │    │
│  │  - Captura eventos do cluster                       │    │
│  │  - Events, Warnings, Errors                         │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Prometheus Integration (Deployment)                │    │
│  │  - Scrape de métricas Prometheus                    │    │
│  │  - Custom metrics support                           │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  FluentBit Logging (DaemonSet)                      │    │
│  │  - Coleta logs de containers                        │    │
│  │  - CRI log parsing                                  │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

### Features

✅ **Deployment automatizado** via Helm e Terraform  
✅ **Zero configuração manual** em kubectl  
✅ **8 alertas críticos** com NRQL  
✅ **Dashboard com 4 páginas** e 20+ widgets  
✅ **Kubernetes Explorer** totalmente funcional  
✅ **Log forwarding** com FluentBit  
✅ **Event collection** para auditoria  
✅ **Metadata injection** em pods  
✅ **Prometheus scraping** para custom metrics  

---

## Arquitetura

### Fluxo de Dados

```
┌─────────────────────────────────────────────────────────────────┐
│                      KUBERNETES CLUSTER                         │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │  Worker 1    │    │  Worker 2    │    │  Worker 3    │     │
│  │              │    │              │    │              │     │
│  │  ┌────────┐  │    │  ┌────────┐  │    │  ┌────────┐  │     │
│  │  │ NR     │  │    │  │ NR     │  │    │  │ NR     │  │     │
│  │  │ Infra  │──┼────┼──│ Infra  │──┼────┼──│ Infra  │  │     │
│  │  │ Agent  │  │    │  │ Agent  │  │    │  │ Agent  │  │     │
│  │  └────────┘  │    │  └────────┘  │    │  └────────┘  │     │
│  │      │       │    │      │       │    │      │       │     │
│  │  ┌────────┐  │    │  ┌────────┐  │    │  ┌────────┐  │     │
│  │  │ Fluent │  │    │  │ Fluent │  │    │  │ Fluent │  │     │
│  │  │  Bit   │──┼────┼──│  Bit   │──┼────┼──│  Bit   │  │     │
│  │  └────────┘  │    │  └────────┘  │    │  └────────┘  │     │
│  │      │       │    │      │       │    │      │       │     │
│  │  ┌────────┐  │    │  ┌────────┐  │    │  ┌────────┐  │     │
│  │  │  App   │  │    │  │  App   │  │    │  │  App   │  │     │
│  │  │  Pods  │  │    │  │  Pods  │  │    │  │  Pods  │  │     │
│  │  └────────┘  │    │  └────────┘  │    │  └────────┘  │     │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘     │
│         │                   │                   │             │
│         └───────────────────┼───────────────────┘             │
│                             │                                 │
│  ┌──────────────────────────▼──────────────────────────────┐  │
│  │              Kube-State-Metrics                         │  │
│  │              Prometheus Endpoint                        │  │
│  │              Events Integration                         │  │
│  └──────────────────────────┬──────────────────────────────┘  │
│                             │                                 │
└─────────────────────────────┼─────────────────────────────────┘
                              │
                              │ HTTPS (TLS 1.2+)
                              │ Port 443
                              │
                              ▼
               ┌──────────────────────────────────┐
               │    NEW RELIC COLLECTOR           │
               │    metric-api.newrelic.com       │
               │    log-api.newrelic.com          │
               └──────────────┬───────────────────┘
                              │
                              │
                              ▼
               ┌──────────────────────────────────┐
               │    NEW RELIC PLATFORM            │
               │                                  │
               │  ┌────────────────────────────┐  │
               │  │  NRDB (Time-Series DB)     │  │
               │  │  - Metrics Storage         │  │
               │  │  - Logs Storage            │  │
               │  │  - Events Storage          │  │
               │  └────────────┬───────────────┘  │
               │               │                  │
               │               ▼                  │
               │  ┌────────────────────────────┐  │
               │  │  NRQL Query Engine         │  │
               │  │  - Dashboards              │  │
               │  │  - Alerts                  │  │
               │  └────────────┬───────────────┘  │
               │               │                  │
               │               ▼                  │
               │  ┌────────────────────────────┐  │
               │  │  UI / API                  │  │
               │  │  - Kubernetes Explorer     │  │
               │  │  - APM                     │  │
               │  └────────────────────────────┘  │
               └──────────────────────────────────┘
```

### Network Requirements

| Origem | Destino | Porta | Protocolo | Propósito |
|--------|---------|-------|-----------|-----------|
| Worker Nodes | metric-api.newrelic.com | 443 | HTTPS | Envio de métricas |
| Worker Nodes | log-api.newrelic.com | 443 | HTTPS | Envio de logs |
| Worker Nodes | infra-api.newrelic.com | 443 | HTTPS | Infrastructure agent |
| Control Plane | Worker Nodes | 10250 | HTTPS | Kubelet API |

---

## Componentes

### 1. Infrastructure Agent (DaemonSet)

**Função**: Coleta métricas de nível de node e container.

**Deployment**:
```yaml
DaemonSet: newrelic-infrastructure
Namespace: newrelic
Replicas: 1 por node
Resources:
  Requests: 100m CPU, 150Mi Memory
  Limits: 300m CPU, 300Mi Memory
```

**Métricas Coletadas**:
- Node CPU usage (cores, percentage)
- Node Memory usage (bytes, percentage)
- Node Disk I/O (read/write bytes)
- Node Network I/O (RX/TX bytes)
- Container CPU usage
- Container Memory usage
- Container filesystem usage

**Configuração** (`newrelic.tf`):
```hcl
nri-bundle = {
  enabled = var.enable_newrelic_monitoring
  
  newrelic-infrastructure = {
    enabled = true
    privileged = true
    
    config = {
      interval = 15
    }
    
    resources = {
      limits = {
        memory = "300Mi"
      }
      requests = {
        cpu    = "100m"
        memory = "150Mi"
      }
    }
  }
}
```

### 2. Kube-State-Metrics

**Função**: Coleta métricas de estado de objetos Kubernetes.

**Deployment**:
```yaml
Deployment: kube-state-metrics
Namespace: newrelic
Replicas: 1
Resources:
  Requests: 100m CPU, 128Mi Memory
  Limits: 200m CPU, 256Mi Memory
```

**Objetos Monitorados**:
- Deployments (replicas, available, unavailable)
- StatefulSets
- DaemonSets
- ReplicaSets
- Pods (status, phase, conditions)
- Nodes (status, conditions)
- PersistentVolumes
- PersistentVolumeClaims
- Services
- ConfigMaps
- Secrets (metadata only)

### 3. Kubernetes Events

**Função**: Captura eventos do cluster para auditoria e troubleshooting.

**Deployment**:
```yaml
Deployment: newrelic-kube-events
Namespace: newrelic
Replicas: 1
Resources:
  Requests: 100m CPU, 128Mi Memory
  Limits: 200m CPU, 256Mi Memory
```

**Eventos Capturados**:
- Pod scheduling events
- Node events (NotReady, DiskPressure, etc.)
- Deployment rollout events
- Volume mount errors
- Image pull errors
- CrashLoopBackOff
- OOMKilled

### 4. Prometheus Integration

**Função**: Scrape de métricas Prometheus para custom metrics.

**Deployment**:
```yaml
Deployment: newrelic-prometheus
Namespace: newrelic
Replicas: 1
Resources:
  Requests: 100m CPU, 128Mi Memory
  Limits: 200m CPU, 256Mi Memory
```

**Configuração**:
```yaml
scrape_configs:
  - job_name: 'kubernetes-pods'
    scrape_interval: 30s
    kubernetes_sd_configs:
      - role: pod
```

### 5. FluentBit Logging

**Função**: Coleta e encaminha logs de containers para New Relic.

**Deployment**:
```yaml
DaemonSet: newrelic-fluent-bit
Namespace: newrelic
Replicas: 1 por node
Resources:
  Requests: 100m CPU, 128Mi Memory
  Limits: 500m CPU, 256Mi Memory
```

**Configuração**:
```hcl
logging = {
  enabled = var.enable_logging
  
  fluentBit = {
    enabled = true
    
    config = {
      criEnabled = true
      service = {
        parsersFile = "parsers.conf"
      }
    }
    
    resources = {
      limits = {
        cpu    = "500m"
        memory = "256Mi"
      }
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}
```

**Logs Coletados**:
- Container stdout/stderr
- Kubernetes audit logs (se habilitado)
- System logs (kubelet, containerd)

---

## Helm Integration

### Chart: nri-bundle

**Versão**: 5.0.x  
**Repository**: https://helm-charts.newrelic.com  
**Namespace**: newrelic (criado automaticamente)

### Terraform Resource

```hcl
resource "helm_release" "newrelic_bundle" {
  count = var.enable_newrelic_monitoring ? 1 : 0

  name       = "newrelic-bundle"
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"
  version    = "~> 5.0"
  namespace  = "newrelic"
  create_namespace = true
  
  timeout = 600
  wait    = true
  
  values = [
    yamlencode({
      global = {
        cluster    = var.cluster_name
        licenseKey = var.newrelic_license_key
      }
      # ... (configuração completa)
    })
  ]

  depends_on = [module.eks]
}
```

### Lifecycle

1. **Install**: Terraform cria namespace e instala chart
2. **Update**: Terraform atualiza valores do chart
3. **Delete**: Terraform remove chart e namespace (opcional)

### Verificação

```bash
# Ver release
helm list -n newrelic

# Ver status
helm status newrelic-bundle -n newrelic

# Ver pods
kubectl get pods -n newrelic

# Ver logs
kubectl logs -n newrelic -l app.kubernetes.io/name=newrelic-infrastructure
```

---

## Métricas Coletadas

### Node Metrics

| Métrica | Tipo | Descrição | Query NRQL |
|---------|------|-----------|-----------|
| `k8s.node.cpuUsedCores` | Gauge | CPU cores utilizados | `FROM K8sNodeSample SELECT average(cpuUsedCores)` |
| `k8s.node.cpuUsedCoreMilliseconds` | Counter | CPU em millicores | `FROM K8sNodeSample SELECT rate(sum(cpuUsedCoreMilliseconds))` |
| `k8s.node.memoryUsedBytes` | Gauge | Memória utilizada (bytes) | `FROM K8sNodeSample SELECT average(memoryUsedBytes)` |
| `k8s.node.memoryAvailableBytes` | Gauge | Memória disponível | `FROM K8sNodeSample SELECT average(memoryAvailableBytes)` |
| `k8s.node.fsUsedBytes` | Gauge | Filesystem utilizado | `FROM K8sNodeSample SELECT average(fsUsedBytes)` |
| `k8s.node.netRxBytesPerSecond` | Counter | Network RX | `FROM K8sNodeSample SELECT rate(sum(netRxBytes))` |
| `k8s.node.netTxBytesPerSecond` | Counter | Network TX | `FROM K8sNodeSample SELECT rate(sum(netTxBytes))` |

### Pod Metrics

| Métrica | Tipo | Descrição | Query NRQL |
|---------|------|-----------|-----------|
| `k8s.pod.cpuUsedCores` | Gauge | CPU do pod | `FROM K8sPodSample SELECT average(cpuUsedCores)` |
| `k8s.pod.memoryUsedBytes` | Gauge | Memória do pod | `FROM K8sPodSample SELECT average(memoryUsedBytes)` |
| `k8s.pod.netRxBytesPerSecond` | Counter | Network RX | `FROM K8sPodSample SELECT rate(sum(netRxBytes))` |
| `k8s.pod.netTxBytesPerSecond` | Counter | Network TX | `FROM K8sPodSample SELECT rate(sum(netTxBytes))` |
| `k8s.pod.fsUsedBytes` | Gauge | Filesystem | `FROM K8sPodSample SELECT average(fsUsedBytes)` |

### Container Metrics

| Métrica | Tipo | Descrição | Query NRQL |
|---------|------|-----------|-----------|
| `k8s.container.cpuUsedCores` | Gauge | CPU do container | `FROM K8sContainerSample SELECT average(cpuUsedCores)` |
| `k8s.container.memoryUsedBytes` | Gauge | Memória do container | `FROM K8sContainerSample SELECT average(memoryUsedBytes)` |
| `k8s.container.restartCount` | Counter | Número de restarts | `FROM K8sContainerSample SELECT latest(restartCount)` |
| `k8s.container.cpuCfsThrottledPeriods` | Counter | CPU throttling | `FROM K8sContainerSample SELECT rate(sum(cpuCfsThrottledPeriods))` |

### Deployment Metrics

| Métrica | Tipo | Descrição | Query NRQL |
|---------|------|-----------|-----------|
| `k8s.deployment.desiredReplicas` | Gauge | Replicas desejadas | `FROM K8sDeploymentSample SELECT latest(desiredReplicas)` |
| `k8s.deployment.availableReplicas` | Gauge | Replicas disponíveis | `FROM K8sDeploymentSample SELECT latest(availableReplicas)` |
| `k8s.deployment.unavailableReplicas` | Gauge | Replicas indisponíveis | `FROM K8sDeploymentSample SELECT latest(unavailableReplicas)` |

---

## Alertas

### 1. High Node CPU Usage

**Condição**: CPU > 80% por 5 minutos

```sql
SELECT average(cpuUsedCores/allocatableCpuCores)*100 
FROM K8sNodeSample 
WHERE clusterName = '{{cluster_name}}' 
FACET nodeName
```

**Threshold**:
- **Critical**: > 80% (configurável)
- **Warning**: > 70%

**Ações**:
- Email para equipe
- Verificar pods consumindo CPU
- Considerar scale up ou out

### 2. High Node Memory Usage

**Condição**: Memory > 80% por 5 minutos

```sql
SELECT average(memoryUsedBytes/allocatableMemoryBytes)*100 
FROM K8sNodeSample 
WHERE clusterName = '{{cluster_name}}' 
FACET nodeName
```

**Threshold**:
- **Critical**: > 80% (configurável)
- **Warning**: > 70%

**Ações**:
- Email para equipe
- Verificar memory leaks
- Verificar cache excessivo
- Considerar scale up

### 3. Node Not Ready

**Condição**: Node em status "NotReady"

```sql
SELECT latest(condition.Ready) 
FROM K8sNodeSample 
WHERE clusterName = '{{cluster_name}}' 
FACET nodeName
```

**Threshold**:
- **Critical**: Ready = 0 por 5 minutos

**Ações**:
- Email IMEDIATO
- Verificar conectividade
- Verificar kubelet logs
- Verificar disk pressure

### 4. High Pod CPU Usage

**Condição**: Pod usando > 90% CPU por 5 minutos

```sql
SELECT average(cpuUsedCores/cpuRequestedCores)*100 
FROM K8sPodSample 
WHERE clusterName = '{{cluster_name}}' 
AND cpuRequestedCores > 0 
FACET podName, namespaceName
```

**Threshold**:
- **Critical**: > 90% (configurável)
- **Warning**: > 80%

**Ações**:
- Email para equipe
- Revisar CPU limits
- Considerar HPA
- Investigar performance

### 5. High Pod Memory Usage

**Condição**: Pod usando > 90% memory por 5 minutos

```sql
SELECT average(memoryUsedBytes/memoryRequestedBytes)*100 
FROM K8sPodSample 
WHERE clusterName = '{{cluster_name}}' 
AND memoryRequestedBytes > 0 
FACET podName, namespaceName
```

**Threshold**:
- **Critical**: > 90% (configurável)
- **Warning**: > 80%

**Ações**:
- Email para equipe
- Verificar memory leaks
- Revisar memory limits
- Considerar restart

### 6. Pod Restart Loop

**Condição**: Pod com > 5 restarts em 5 minutos

```sql
SELECT latest(restartCount) 
FROM K8sContainerSample 
WHERE clusterName = '{{cluster_name}}' 
FACET containerName, podName, namespaceName
```

**Threshold**:
- **Critical**: > 5 restarts

**Ações**:
- Email IMEDIATO
- Verificar logs do pod
- Verificar eventos
- Investigar CrashLoopBackOff

### 7. High CPU Throttling

**Condição**: Throttling > 50% por 5 minutos

```sql
SELECT rate(sum(cpuCfsThrottledPeriods), 1 minute) / rate(sum(cpuCfsPeriods), 1 minute) * 100 
FROM K8sContainerSample 
WHERE clusterName = '{{cluster_name}}' 
FACET containerName, podName
```

**Threshold**:
- **Critical**: > 50%
- **Warning**: > 30%

**Ações**:
- Email para equipe
- Revisar CPU limits
- Considerar aumentar limits
- Verificar performance

### 8. Deployment Replica Mismatch

**Condição**: Replicas disponíveis < desejadas por 10 minutos

```sql
SELECT latest(desiredReplicas - availableReplicas) 
FROM K8sDeploymentSample 
WHERE clusterName = '{{cluster_name}}' 
FACET deploymentName, namespaceName
```

**Threshold**:
- **Critical**: Diferença > 0 por 10 minutos

**Ações**:
- Email para equipe
- Verificar eventos do deployment
- Verificar recursos disponíveis
- Verificar image pull

---

## Dashboard

### URL

```bash
terraform output newrelic_dashboard_url
```

### Estrutura (4 Páginas)

#### Página 1: Cluster Overview

**Widgets (8)**:

1. **Cluster Status** (Billboard)
```sql
SELECT uniqueCount(nodeName) AS 'Total Nodes',
       sum(allocatableCpuCores) AS 'Total CPU Cores',
       sum(allocatableMemoryBytes)/1073741824 AS 'Total Memory (GB)'
FROM K8sNodeSample
WHERE clusterName = '{{cluster_name}}'
SINCE 5 minutes ago
```

2. **Node CPU Usage** (Line Chart)
```sql
SELECT average(cpuUsedCores/allocatableCpuCores)*100 AS 'CPU Usage %'
FROM K8sNodeSample
WHERE clusterName = '{{cluster_name}}'
FACET nodeName
TIMESERIES AUTO
```

3. **Node Memory Usage** (Line Chart)
```sql
SELECT average(memoryUsedBytes/allocatableMemoryBytes)*100 AS 'Memory Usage %'
FROM K8sNodeSample
WHERE clusterName = '{{cluster_name}}'
FACET nodeName
TIMESERIES AUTO
```

4. **Pods by Namespace** (Bar Chart)
```sql
SELECT uniqueCount(podName) AS 'Pod Count'
FROM K8sPodSample
WHERE clusterName = '{{cluster_name}}'
FACET namespaceName
```

5. **Pod Status Distribution** (Pie Chart)
```sql
SELECT count(*) AS 'Count'
FROM K8sPodSample
WHERE clusterName = '{{cluster_name}}'
FACET status
```

6. **Container Restarts** (Line Chart)
```sql
SELECT sum(restartCount) AS 'Total Restarts'
FROM K8sContainerSample
WHERE clusterName = '{{cluster_name}}'
FACET namespaceName
TIMESERIES AUTO
```

7. **Network Throughput - RX** (Area Chart)
```sql
SELECT rate(sum(netRxBytes), 1 minute)/1048576 AS 'RX MB/min'
FROM K8sNodeSample
WHERE clusterName = '{{cluster_name}}'
FACET nodeName
TIMESERIES AUTO
```

8. **Network Throughput - TX** (Area Chart)
```sql
SELECT rate(sum(netTxBytes), 1 minute)/1048576 AS 'TX MB/min'
FROM K8sNodeSample
WHERE clusterName = '{{cluster_name}}'
FACET nodeName
TIMESERIES AUTO
```

#### Página 2: Pods & Containers

**Widgets (6)**:

1. **Top Pods by CPU** (Table)
```sql
SELECT latest(podName) AS 'Pod',
       latest(namespaceName) AS 'Namespace',
       average(cpuUsedCores) AS 'CPU Cores'
FROM K8sPodSample
WHERE clusterName = '{{cluster_name}}'
FACET podName, namespaceName
LIMIT 20
```

2. **Top Pods by Memory** (Table)
```sql
SELECT latest(podName) AS 'Pod',
       latest(namespaceName) AS 'Namespace',
       average(memoryUsedBytes)/1048576 AS 'Memory (MB)'
FROM K8sPodSample
WHERE clusterName = '{{cluster_name}}'
FACET podName, namespaceName
LIMIT 20
```

3. **Container CPU by Namespace** (Area Chart)
```sql
SELECT average(cpuUsedCores) AS 'CPU Cores'
FROM K8sContainerSample
WHERE clusterName = '{{cluster_name}}'
FACET namespaceName
TIMESERIES AUTO
```

4. **Container Memory by Namespace** (Area Chart)
```sql
SELECT average(memoryUsedBytes)/1073741824 AS 'Memory (GB)'
FROM K8sContainerSample
WHERE clusterName = '{{cluster_name}}'
FACET namespaceName
TIMESERIES AUTO
```

5. **CPU Throttling** (Line Chart)
```sql
SELECT rate(sum(cpuCfsThrottledPeriods), 1 minute) / rate(sum(cpuCfsPeriods), 1 minute) * 100 AS 'Throttling %'
FROM K8sContainerSample
WHERE clusterName = '{{cluster_name}}'
FACET namespaceName
TIMESERIES AUTO
```

6. **Filesystem Usage** (Bar Chart)
```sql
SELECT average(fsUsedBytes/fsCapacityBytes)*100 AS 'Usage %'
FROM K8sPodSample
WHERE clusterName = '{{cluster_name}}'
AND fsCapacityBytes > 0
FACET podName
LIMIT 20
```

#### Página 3: Deployments & Services

**Widgets (4)**:

1. **Deployment Status** (Table)
```sql
SELECT latest(deploymentName) AS 'Deployment',
       latest(namespaceName) AS 'Namespace',
       latest(desiredReplicas) AS 'Desired',
       latest(availableReplicas) AS 'Available',
       latest(unavailableReplicas) AS 'Unavailable'
FROM K8sDeploymentSample
WHERE clusterName = '{{cluster_name}}'
FACET deploymentName, namespaceName
```

2. **Replica Availability** (Line Chart)
```sql
SELECT latest(availableReplicas)/latest(desiredReplicas)*100 AS 'Availability %'
FROM K8sDeploymentSample
WHERE clusterName = '{{cluster_name}}'
AND desiredReplicas > 0
FACET deploymentName
TIMESERIES AUTO
```

3. **Services Count** (Billboard)
```sql
SELECT uniqueCount(serviceName) AS 'Total Services'
FROM K8sServiceSample
WHERE clusterName = '{{cluster_name}}'
```

4. **Recent Events** (Table)
```sql
SELECT timestamp, message, reason, involvedObjectKind, involvedObjectName
FROM InfrastructureEvent
WHERE category = 'kubernetes'
AND clusterName = '{{cluster_name}}'
ORDER BY timestamp DESC
LIMIT 50
```

#### Página 4: Storage

**Widgets (4)**:

1. **PersistentVolume Status** (Pie Chart)
```sql
SELECT count(*) AS 'Count'
FROM K8sPersistentVolumeSample
WHERE clusterName = '{{cluster_name}}'
FACET phase
```

2. **PersistentVolumeClaim Status** (Pie Chart)
```sql
SELECT count(*) AS 'Count'
FROM K8sPersistentVolumeClaimSample
WHERE clusterName = '{{cluster_name}}'
FACET phase
```

3. **Storage Classes** (Bar Chart)
```sql
SELECT count(*) AS 'Volume Count'
FROM K8sPersistentVolumeSample
WHERE clusterName = '{{cluster_name}}'
FACET storageClass
```

4. **Volume Usage Over Time** (Line Chart)
```sql
SELECT average(fsUsedBytes)/1073741824 AS 'Used (GB)'
FROM K8sVolumeSample
WHERE clusterName = '{{cluster_name}}'
FACET volumeName
TIMESERIES AUTO
```

---

## Troubleshooting

### Problema: Pods New Relic não iniciam

**Sintomas**:
```bash
$ kubectl get pods -n newrelic
NAME                               READY   STATUS             RESTARTS   AGE
newrelic-infrastructure-abc123     0/1     CrashLoopBackOff   5          5m
```

**Diagnóstico**:
```bash
# Ver logs
kubectl logs -n newrelic newrelic-infrastructure-abc123

# Ver eventos
kubectl describe pod -n newrelic newrelic-infrastructure-abc123
```

**Soluções**:

1. **License Key inválida**:
```bash
# Verificar secret
kubectl get secret -n newrelic newrelic-bundle-newrelic-infrastructure-config -o yaml

# Recriar com license key correta
terraform apply -replace='helm_release.newrelic_bundle[0]'
```

2. **Permissões insuficientes**:
```bash
# Verificar RBAC
kubectl get clusterrolebinding | grep newrelic
kubectl get clusterrole | grep newrelic

# Reinstalar
helm uninstall newrelic-bundle -n newrelic
terraform apply
```

### Problema: Métricas não aparecem no New Relic

**Sintomas**: Dashboard vazio, sem dados de métricas.

**Diagnóstico**:
```bash
# Verificar se pods estão enviando dados
kubectl logs -n newrelic -l app.kubernetes.io/name=newrelic-infrastructure | grep "successfully sent"

# Verificar conectividade
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- https://metric-api.newrelic.com/health
```

**Soluções**:

1. **Firewall/Security Group bloqueando**:
- Liberar acesso HTTPS (443) para `*.newrelic.com`
- Verificar NAT Gateway funcionando

2. **Account ID incorreto**:
```hcl
# Verificar em terraform.tfvars
newrelic_account_id = "1234567"  # Deve ser 7 dígitos
```

3. **Região incorreta**:
```hcl
# US account
newrelic_region = "US"

# EU account
newrelic_region = "EU"
```

### Problema: Alertas não disparando

**Sintomas**: Threshold ultrapassado mas sem notificação.

**Diagnóstico**:
```bash
# Ver política no New Relic
terraform output newrelic_alert_policy_id

# Verificar workflow
# New Relic UI > Alerts & AI > Workflows
```

**Soluções**:

1. **Email incorreto**:
```hcl
alert_email = "team@example.com"  # Verificar typo
```

2. **Workflow não ativado**:
- Verificar no New Relic UI se workflow está enabled

3. **Condição nunca triggered**:
```sql
-- Testar NRQL no Query Builder
SELECT average(cpuUsedCores/allocatableCpuCores)*100 
FROM K8sNodeSample 
WHERE clusterName = 'tech-challenge-cluster'
FACET nodeName
SINCE 30 minutes ago
```

### Problema: High CPU no Infrastructure Agent

**Sintomas**: Pods do New Relic consumindo muita CPU.

**Diagnóstico**:
```bash
kubectl top pods -n newrelic
```

**Soluções**:

1. **Reduzir intervalo de coleta**:
```hcl
config = {
  interval = 30  # Aumentar de 15 para 30 segundos
}
```

2. **Ajustar resource limits**:
```hcl
resources = {
  limits = {
    cpu = "200m"  # Reduzir de 300m
  }
}
```

### Problema: Logs não aparecem

**Sintomas**: Sem logs no New Relic Logs.

**Diagnóstico**:
```bash
# Verificar FluentBit
kubectl get pods -n newrelic | grep fluent
kubectl logs -n newrelic -l app.kubernetes.io/name=fluent-bit
```

**Soluções**:

1. **Logging desabilitado**:
```hcl
enable_logging = true
```

2. **CRI parser incorreto**:
```hcl
config = {
  criEnabled = true  # Para containerd/CRI-O
}
```

3. **Permissões de leitura de logs**:
```bash
# Verificar se FluentBit tem acesso a /var/log
kubectl describe daemonset -n newrelic newrelic-fluent-bit
```

---

## Performance Impact

### Resource Usage (por node)

| Componente | CPU Request | CPU Limit | Memory Request | Memory Limit |
|------------|-------------|-----------|----------------|--------------|
| Infrastructure Agent | 100m | 300m | 150Mi | 300Mi |
| FluentBit | 100m | 500m | 128Mi | 256Mi |
| **Total por Node** | **200m** | **800m** | **278Mi** | **556Mi** |

### Cluster-Wide Resources

| Componente | Replicas | CPU Request | Memory Request |
|------------|----------|-------------|----------------|
| Kube-State-Metrics | 1 | 100m | 128Mi |
| Events Integration | 1 | 100m | 128Mi |
| Prometheus | 1 | 100m | 128Mi |
| **Total Cluster** | **3** | **300m** | **384Mi** |

### Total Impact

**Para cluster com 2 nodes**:
- CPU Total: (200m × 2) + 300m = 700m (0.7 cores)
- Memory Total: (278Mi × 2) + 384Mi = 940Mi (~1 GB)

**Porcentagem do cluster** (2x t3.small = 4 vCPU, 4 GB):
- CPU: 17.5%
- Memory: 25%

### Network Impact

- **Outbound Traffic**: ~5-10 MB/min (comprimido)
- **Data Ingestion**: ~100-200 MB/dia (métricas + logs)
- **New Relic Free Tier**: 100 GB/mês (suficiente)

### Recomendações

✅ **OK para Produção** - Overhead aceitável (<20% recursos)  
✅ **Ajuste limits** para produção com mais pods  
✅ **Use HPA** se overhead ultrapassar 30%  
⚠️ **Monitore** data ingestion para não ultrapassar free tier  

---

## Custos

### New Relic Free Tier

✅ **100 GB/mês** de data ingestion (permanente)  
✅ **1 usuário full platform**  
✅ **Unlimited hosts**  
✅ **Alertas inclusos**  
✅ **Dashboards inclusos**  

### Data Ingestion Estimada

**Dev Environment (2 nodes, 10 pods)**:
- Métricas: ~30 MB/dia
- Logs: ~50 MB/dia
- Events: ~10 MB/dia
- **Total**: ~90 MB/dia = **2.7 GB/mês** ✅ Dentro do free tier

**Production (5 nodes, 50 pods)**:
- Métricas: ~100 MB/dia
- Logs: ~200 MB/dia
- Events: ~30 MB/dia
- **Total**: ~330 MB/dia = **10 GB/mês** ✅ Dentro do free tier

### Custos AWS (não relacionados ao New Relic)

- EKS Control Plane: $72/mês
- EC2 Nodes: $15-90/mês (dependendo de quantity/tipo)
- EBS Volumes: $2-10/mês
- NAT Gateway: $32/mês
- **Total AWS**: $121-204/mês

---

## Referências

### Documentação Oficial

- 📘 [New Relic Kubernetes Integration](https://docs.newrelic.com/docs/kubernetes-pixie/kubernetes-integration/get-started/introduction-kubernetes-integration/)
- 📘 [Helm Chart Documentation](https://github.com/newrelic/helm-charts/tree/master/charts/nri-bundle)
- 📘 [NRQL Reference](https://docs.newrelic.com/docs/query-your-data/nrql-new-relic-query-language/get-started/introduction-nrql-new-relics-query-language/)
- 📘 [Alert Conditions](https://docs.newrelic.com/docs/alerts-applied-intelligence/new-relic-alerts/alert-conditions/create-nrql-alert-conditions/)
- 📘 [Kubernetes Explorer](https://docs.newrelic.com/docs/kubernetes-pixie/kubernetes-integration/understand-use-data/kubernetes-cluster-explorer/)

### Terraform Providers

- 🔧 [New Relic Provider](https://registry.terraform.io/providers/newrelic/newrelic/latest/docs)
- 🔧 [Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- 🔧 [Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)

---

**Documento Version**: 1.0.0  
**Last Updated**: Janeiro 2026  
**Author**: Tech Challenge - Grupo 99  
**Status**: ✅ Production Ready
