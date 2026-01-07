# Tech Challenge - EKS Infrastructure

> Infrastructure as Code (IaC) para cluster Kubernetes EKS com observabilidade completa via New Relic

[![Terraform](https://img.shields.io/badge/Terraform-≥1.2.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS_1.29-FF9900?logo=amazon-aws)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![New Relic](https://img.shields.io/badge/New_Relic-Observability-00AC69?logo=new-relic)](https://newrelic.com/)

---

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Features](#-features)
- [Arquitetura](#-arquitetura)
- [Quick Start](#-quick-start)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Configuração](#-configuração)
- [Monitoramento](#-monitoramento)
- [Custos](#-custos)
- [Comandos Úteis](#-comandos-úteis)

---

## 🎯 Visão Geral

Este repositório contém a infraestrutura completa para o cluster Kubernetes do Tech Challenge, incluindo:

- **EKS Cluster 1.29** com node groups gerenciados
- **Observabilidade New Relic** completa via Helm
- **8 alertas críticos** com notificações por email
- **Dashboard customizado** com 4 páginas e 20+ widgets
- **Kubernetes Integration** para métricas de pods, nodes, deployments
- **Logging integration** com FluentBit

### Tecnologias

- **Terraform** ≥ 1.2.0 - Infrastructure as Code
- **AWS EKS** - Kubernetes 1.29 gerenciado
- **New Relic** - Plataforma de observabilidade
- **Helm** - Package manager para Kubernetes
- **FluentBit** - Log forwarding

---

## ✨ Features

### Infraestrutura
- ✅ EKS Cluster 1.29
- ✅ Managed Node Groups (t3.small, auto-scaling 1-3)
- ✅ VPC privada com NAT Gateway
- ✅ Subnets públicas e privadas (2 AZs)
- ✅ Security Groups configurados
- ✅ IAM Roles para service accounts (IRSA ready)
- ✅ S3 bucket para tfstate backend

### Observabilidade New Relic
- ✅ **Kubernetes Integration** via Helm (nri-bundle 5.0+)
- ✅ **Infrastructure Agent** rodando em cada node
- ✅ **Kube-State-Metrics** para métricas de objetos K8s
- ✅ **Prometheus Integration** para métricas customizadas
- ✅ **Events Integration** para eventos do cluster
- ✅ **Logging Integration** com FluentBit
- ✅ **8 alertas críticos**: Node CPU/Memory, Pod CPU/Memory/Restarts, CPU Throttling, Replica Mismatch
- ✅ **Dashboard com 4 páginas**: Cluster Overview, Pods & Containers, Deployments & Services, Storage
- ✅ **20+ widgets**: Métricas em tempo real
- ✅ **Email notifications** para incidentes

### Automação
- ✅ Documentação completa
- ✅ Exemplos de configuração
- ✅ IaC 100% versionado
- ✅ Helm charts gerenciados via Terraform

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                           AWS CLOUD                             │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                  VPC (10.0.0.0/16)                     │    │
│  │                                                        │    │
│  │  ┌──────────────────┐    ┌──────────────────┐        │    │
│  │  │ Public Subnet    │    │ Public Subnet    │        │    │
│  │  │ 10.0.101.0/24    │    │ 10.0.102.0/24    │        │    │
│  │  │ (AZ-a)           │    │ (AZ-b)           │        │    │
│  │  │                  │    │                  │        │    │
│  │  │  ┌─────────┐     │    │                  │        │    │
│  │  │  │   NAT   │     │    │                  │        │    │
│  │  │  │ Gateway │     │    │                  │        │    │
│  │  │  └─────────┘     │    │                  │        │    │
│  │  └────────┬─────────┘    └──────────────────┘        │    │
│  │           │                                           │    │
│  │  ┌────────▼──────────┐    ┌──────────────────┐       │    │
│  │  │ Private Subnet    │    │ Private Subnet   │       │    │
│  │  │ 10.0.1.0/24       │    │ 10.0.2.0/24      │       │    │
│  │  │ (AZ-a)            │    │ (AZ-b)           │       │    │
│  │  │                   │    │                  │       │    │
│  │  │  ┌─────────────┐  │    │  ┌─────────────┐│       │    │
│  │  │  │ Worker Node │  │    │  │ Worker Node ││       │    │
│  │  │  │   (t3.small)│  │    │  │  (t3.small) ││       │    │
│  │  │  │             │  │    │  │             ││       │    │
│  │  │  │ ┌─────────┐ │  │    │  │ ┌─────────┐ ││       │    │
│  │  │  │ │  Pods   │ │  │    │  │ │  Pods   │ ││       │    │
│  │  │  │ │ ┌─────┐ │ │  │    │  │ │ ┌─────┐ │ ││       │    │
│  │  │  │ │ │ NR  │ │ │  │    │  │ │ │ NR  │ │ ││       │    │
│  │  │  │ │ │Agent│ │ │  │    │  │ │ │Agent│ │ ││       │    │
│  │  │  │ │ └─────┘ │ │  │    │  │ │ └─────┘ │ ││       │    │
│  │  │  │ └─────────┘ │  │    │  │ └─────────┘ ││       │    │
│  │  │  └─────────────┘  │    │  └─────────────┘│       │    │
│  │  └───────────────────┘    └──────────────────┘       │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐      │
│  │          EKS Control Plane (Managed by AWS)          │      │
│  │                  Kubernetes 1.29                     │      │
│  └──────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS/TLS
                              ▼
                    ┌───────────────────────────────┐
                    │     NEW RELIC PLATFORM        │
                    │                               │
                    │  ┌─────────────────────────┐  │
                    │  │  Kubernetes Explorer    │  │
                    │  │  - Cluster Metrics      │  │
                    │  │  - Pod Metrics          │  │
                    │  │  - Node Metrics         │  │
                    │  │  - Events               │  │
                    │  └──────────┬──────────────┘  │
                    │             │                 │
                    │             ▼                 │
                    │  ┌─────────────────────────┐  │
                    │  │  NRQL Alert Engine      │  │
                    │  │  - 8 Critical Alerts    │  │
                    │  └──────────┬──────────────┘  │
                    │             │                 │
                    │             ▼                 │
                    │  ┌─────────────────────────┐  │
                    │  │  Email Notifications    │  │
                    │  └─────────────────────────┘  │
                    │                               │
                    │  ┌─────────────────────────┐  │
                    │  │  Dashboard              │  │
                    │  │  - 4 Pages              │  │
                    │  │  - 20+ Widgets          │  │
                    │  └─────────────────────────┘  │
                    └───────────────────────────────┘
```

---

## 🚀 Quick Start

### 1. Obter Credenciais New Relic (5 min)

1. Login: https://one.newrelic.com
2. **Administration** > **API Keys**
3. Copiar **Account ID** (7 dígitos)
4. Criar **User API Key** (começa com `NRAK-`)
5. Obter **License Key** (Ingest - License)

### 2. Configurar Variáveis (3 min)

```bash
cd tech_challenge_k8s_infra
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com suas credenciais
```

### 3. Deploy (10 min)

```bash
terraform init
terraform plan
terraform apply
```

### 4. Configurar kubectl (2 min)

```bash
aws eks update-kubeconfig --name tech-challenge-cluster --region us-east-1
kubectl get nodes
kubectl get pods -n newrelic
```

### 5. Verificar (2 min)

```bash
# Ver dashboard URL
terraform output newrelic_dashboard_url

# Ver pods New Relic
kubectl get pods -n newrelic
```

---

## 📁 Estrutura do Projeto

```
tech_challenge_k8s_infra/
├── main.tf                         # Providers (AWS, New Relic, K8s, Helm)
├── variables.tf                    # Variáveis (15 total)
├── eks.tf                          # EKS cluster definition
├── vpc.tf                          # VPC e networking
├── s3.tf                           # S3 para backend
├── outputs.tf                      # Outputs (13 total)
├── newrelic.tf                     # Observabilidade completa (1000+ linhas)
├── backend.tf                      # Terraform backend
│
├── README.md                       # Este arquivo
└── terraform.tfvars.example        # Exemplo de configuração
```

---

## ⚙️ Configuração

### Variáveis Obrigatórias

```hcl
# New Relic
newrelic_account_id  = "1234567"
newrelic_api_key     = "NRAK-XXXXXXXXXXXXXXXXXXXXX"
newrelic_license_key = "euXXXXNRAL"
alert_email          = "team@example.com"

# AWS
aws_region = "us-east-1"

# EKS
cluster_name       = "tech-challenge-cluster"
node_instance_type = "t3.small"
desired_capacity   = 2
```

### Variáveis Opcionais (com defaults)

```hcl
# Observabilidade
enable_newrelic_monitoring = true
enable_logging            = true

# Alertas (thresholds)
alert_node_cpu_threshold    = 80   # Percent
alert_node_memory_threshold = 80   # Percent
alert_pod_cpu_threshold     = 90   # Percent
alert_pod_memory_threshold  = 90   # Percent

# Ambiente
environment = "dev"  # dev, staging, prod
```

---

## 📊 Monitoramento

### Métricas Coletadas

#### Cluster Level
- Node count, CPU cores, Memory (GB)
- Cluster-wide resource utilization

#### Node Level
- CPU usage (cores & percentage)
- Memory usage (bytes & percentage)
- Network RX/TX (bytes/sec)
- Filesystem usage
- Node conditions (Ready, DiskPressure, MemoryPressure)

#### Pod Level
- CPU usage per pod
- Memory usage per pod
- Network throughput
- Filesystem usage
- Pod status (Running, Pending, Failed)
- Restart counts

#### Container Level
- CPU usage & throttling
- Memory usage & limits
- Restart counts

#### Workload Level (Deployments, StatefulSets, DaemonSets)
- Desired vs Ready replicas
- Available replicas
- Pod distribution

#### Storage
- PersistentVolume status
- PersistentVolumeClaim status
- Storage class distribution

### Alertas Configurados (8 condições)

| Alerta | Threshold | Duração | Ação |
|--------|-----------|---------|------|
| **High Node CPU** | > 80% | 5 min | Email |
| **High Node Memory** | > 80% | 5 min | Email |
| **Node Not Ready** | < 1 (not ready) | 5 min | Email |
| **High Pod CPU** | > 90% | 5 min | Email |
| **High Pod Memory** | > 90% | 5 min | Email |
| **Pod Restart Loop** | > 5 restarts | 5 min | Email |
| **High CPU Throttling** | > 50% | 5 min | Email |
| **Replica Mismatch** | > 0 missing | 10 min | Email |

### Dashboard (4 páginas)

**Página 1: Cluster Overview** (8 widgets)
- Cluster status
- Node CPU/Memory usage
- Pod count by namespace
- Pod status distribution
- Container restarts
- Network RX/TX

**Página 2: Pods & Containers** (6 widgets)
- Top CPU consuming pods
- Top memory consuming pods
- Container CPU by namespace
- Container memory by namespace
- CPU throttling
- Filesystem usage

**Página 3: Deployments & Services** (4 widgets)
- Deployment status
- Replica availability
- Services count
- Recent Kubernetes events
- HPA status

**Página 4: Storage** (4 widgets)
- PV status
- PVC status
- Storage class distribution
- Volume usage over time

**Acesso**:
```bash
terraform output newrelic_dashboard_url
```

---

## 💰 Custos

### Ambiente Dev (Estimativa Mensal)

```
EKS Control Plane:             $72
EC2 nodes (2x t3.small):       $30
EBS volumes (2x 20GB):         $4
NAT Gateway:                   $32
Data transfer:                 $5
New Relic (Free Tier):         $0
───────────────────────────────────
Total:                         ~$143/mês
```

### Ambiente Produção (Estimativa Mensal)

```
EKS Control Plane:             $72
EC2 nodes (3x t3.medium):      $90
EBS volumes (3x 50GB):         $15
NAT Gateway (Multi-AZ):        $64
Data transfer:                 $20
Load Balancers:                $20
New Relic (Free Tier):         $0
───────────────────────────────────
Total:                         ~$281/mês
```

**💡 Dica**: New Relic free tier inclui 100GB/mês permanentemente.

**Otimização**:
- Use Spot Instances (economize 70-90%)
- Single NAT Gateway em dev (já configurado)
- Cluster Autoscaler para scale down
- Right-size de instance types

---

## 🔧 Comandos Úteis

### Terraform

```bash
# Inicializar
terraform init

# Planejar
terraform plan

# Aplicar
terraform apply

# Ver outputs
terraform output

# Destruir (CUIDADO!)
terraform destroy
```

### Kubernetes

```bash
# Configurar kubectl
aws eks update-kubeconfig --name tech-challenge-cluster --region us-east-1

# Ver nodes
kubectl get nodes

# Ver pods em todos namespaces
kubectl get pods --all-namespaces

# Ver pods New Relic
kubectl get pods -n newrelic

# Ver logs do New Relic
kubectl logs -n newrelic -l app.kubernetes.io/name=newrelic-infrastructure

# Ver eventos
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Descrever node
kubectl describe node <node-name>

# Ver uso de recursos
kubectl top nodes
kubectl top pods --all-namespaces
```

### New Relic

```bash
# Ver dashboard
terraform output newrelic_dashboard_url

# Verificar integração
kubectl get pods -n newrelic
kubectl logs -f -n newrelic <pod-name>
```

### Troubleshooting

```bash
# Ver logs do Helm release
helm list -n newrelic
helm status newrelic-bundle -n newrelic

# Reinstalar New Relic bundle
helm uninstall newrelic-bundle -n newrelic
terraform apply -replace='helm_release.newrelic_bundle[0]'

# Ver eventos do cluster
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Debug de pods
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

---

## 🔐 Segurança

### Best Practices Implementadas

- ✅ **VPC Privada**: Nodes em subnets privadas
- ✅ **NAT Gateway**: Acesso controlado à internet
- ✅ **IAM Roles**: IRSA ready para service accounts
- ✅ **Security Groups**: Tráfego controlado
- ✅ **Secrets Management**: Variáveis sensíveis no terraform.tfvars (não versionado)
- ✅ **Network Policies**: Ready para implementação
- ✅ **Pod Security**: Ready para pod security standards

### Checklist

- [ ] `terraform.tfvars` adicionado ao `.gitignore` ✅ (já configurado)
- [ ] Credenciais AWS configuradas (não em código)
- [ ] New Relic API Keys rotacionadas regularmente
- [ ] Security Groups revisados
- [ ] Network policies implementadas (se necessário)
- [ ] Pod security standards aplicados (se necessário)
- [ ] Container images escaneadas por vulnerabilidades

---

## 📝 Licença

Este projeto está licenciado sob a licença MIT - veja [LICENSE](LICENSE) para detalhes.

---

## 👥 Equipe

**Tech Challenge - Grupo 99**
- FIAP Pós-Tech
- Arquitetura de Software

---

## 📞 Suporte

### Documentação Externa
- 🌐 [New Relic Kubernetes Integration](https://docs.newrelic.com/docs/kubernetes-pixie/kubernetes-integration/get-started/introduction-kubernetes-integration/)
- 🌐 [AWS EKS Docs](https://docs.aws.amazon.com/eks/)
- 🌐 [Terraform EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

---

**Versão**: 1.0.0  
**Última Atualização**: Janeiro 2026  
**Status**: ✅ Production Ready
