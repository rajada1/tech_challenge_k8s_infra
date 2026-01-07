# Checklist - New Relic EKS Deployment

> Checklist completo para validar deployment de observabilidade New Relic no EKS

**Projeto**: Tech Challenge - EKS Infrastructure  
**Versão**: 1.0.0  
**Status**: Ready for use

---

## 📋 Como Usar Este Checklist

1. Execute os comandos na ordem apresentada
2. Marque ✅ quando o item estiver OK
3. Se encontrar ❌, consulte a seção **Troubleshooting** ao final
4. Todos os itens devem estar ✅ para considerar deployment bem-sucedido

---

## 🎯 Pré-Deployment

### Credenciais e Configuração

- [ ] **New Relic Account ID** obtido (7 dígitos)
- [ ] **New Relic User API Key** criada (começa com `NRAK-`)
- [ ] **New Relic License Key** obtida (começa com `NRAL` ou `euXXXXNRAL`)
- [ ] **Email** para alertas configurado
- [ ] **terraform.tfvars** criado e preenchido
- [ ] **AWS credentials** configuradas (`aws configure`)
- [ ] **kubectl** instalado (≥ 1.27)
- [ ] **helm** instalado (≥ 3.0)
- [ ] **terraform** instalado (≥ 1.2.0)

### Verificação de Ferramentas

Execute:
```bash
terraform version
aws --version
kubectl version --client
helm version
```

**Resultado Esperado**:
```
✅ Terraform v1.2.0 ou superior
✅ aws-cli/2.0 ou superior
✅ kubectl v1.27 ou superior
✅ helm v3.0 ou superior
```

- [ ] **Todas as ferramentas instaladas** e versões corretas

---

## 🚀 Durante o Deployment

### 1. Terraform Init

Execute:
```bash
terraform init
```

**Verificar**:
- [ ] ✅ "Terraform has been successfully initialized!"
- [ ] ✅ Providers baixados: aws, newrelic, kubernetes, helm
- [ ] ✅ Sem erros

### 2. Terraform Plan

Execute:
```bash
terraform plan
```

**Verificar**:
- [ ] ✅ Plan cria ~40-50 resources
- [ ] ✅ Sem erros de validação
- [ ] ✅ Variáveis carregadas corretamente
- [ ] ✅ Resources incluem:
  - [ ] EKS cluster
  - [ ] VPC e subnets
  - [ ] helm_release.newrelic_bundle
  - [ ] newrelic_alert_policy
  - [ ] newrelic_one_dashboard

### 3. Terraform Apply

Execute:
```bash
terraform apply
```

**Durante aplicação**:
- [ ] ✅ Comando aceito com "yes"
- [ ] ✅ EKS cluster sendo criado (leva ~8-10 min)
- [ ] ✅ VPC criada
- [ ] ✅ Helm chart sendo instalado
- [ ] ✅ New Relic resources sendo criados

**Ao Final**:
- [ ] ✅ "Apply complete! Resources: XX added, 0 changed, 0 destroyed"
- [ ] ✅ Outputs exibidos

### 4. Verificar Outputs

Execute:
```bash
terraform output
```

**Verificar presença de**:
- [ ] ✅ `cluster_endpoint`
- [ ] ✅ `cluster_name`
- [ ] ✅ `newrelic_dashboard_url`
- [ ] ✅ `newrelic_alert_policy_id`
- [ ] ✅ `newrelic_integration_installed` = true
- [ ] ✅ `cluster_id`
- [ ] ✅ `vpc_id`

---

## ☸️ Pós-Deployment: Kubernetes

### 1. Configurar kubectl

Execute:
```bash
aws eks update-kubeconfig --name tech-challenge-cluster --region us-east-1
```

**Verificar**:
- [ ] ✅ "Added new context" aparece
- [ ] ✅ Sem erros

Testar:
```bash
kubectl cluster-info
```

- [ ] ✅ Kubernetes control plane acessível

### 2. Verificar Nodes

Execute:
```bash
kubectl get nodes
```

**Resultado Esperado**:
```
NAME                             STATUS   ROLES    AGE   VERSION
ip-10-0-1-xxx.ec2.internal       Ready    <none>   5m    v1.29.0
ip-10-0-2-xxx.ec2.internal       Ready    <none>   5m    v1.29.0
```

**Verificar**:
- [ ] ✅ Todos nodes em STATUS = `Ready`
- [ ] ✅ Número de nodes correto (default: 2)
- [ ] ✅ VERSION = v1.29.x

Detalhes:
```bash
kubectl get nodes -o wide
```

- [ ] ✅ Nodes em subnets privadas (10.0.x.x)
- [ ] ✅ Internal IPs corretas

### 3. Verificar Namespace New Relic

Execute:
```bash
kubectl get namespace newrelic
```

**Resultado Esperado**:
```
NAME       STATUS   AGE
newrelic   Active   3m
```

- [ ] ✅ Namespace `newrelic` existe
- [ ] ✅ STATUS = `Active`

### 4. Verificar Pods New Relic

Execute:
```bash
kubectl get pods -n newrelic
```

**Resultado Esperado** (exemplo com 2 nodes):
```
NAME                                          READY   STATUS    RESTARTS   AGE
newrelic-infrastructure-abc123                1/1     Running   0          3m
newrelic-infrastructure-def456                1/1     Running   0          3m
newrelic-kube-state-metrics-xxx               1/1     Running   0          3m
newrelic-kube-events-yyy                      1/1     Running   0          3m
newrelic-prometheus-zzz                       1/1     Running   0          3m
newrelic-fluent-bit-aaa                       1/1     Running   0          3m
newrelic-fluent-bit-bbb                       1/1     Running   0          3m
```

**Verificar**:
- [ ] ✅ Todos pods em STATUS = `Running`
- [ ] ✅ READY = `1/1` (ou `x/x`)
- [ ] ✅ RESTARTS baixo (≤ 2)
- [ ] ✅ Pods `newrelic-infrastructure` = número de nodes
- [ ] ✅ Pods `newrelic-fluent-bit` = número de nodes
- [ ] ✅ Pods deployments (kube-state-metrics, events, prometheus) = 1 cada

**Se houver pods em CrashLoopBackOff ou Error**:
```bash
kubectl describe pod -n newrelic <pod-name>
kubectl logs -n newrelic <pod-name>
```

- [ ] ✅ Nenhum pod em estado de erro

### 5. Verificar Helm Release

Execute:
```bash
helm list -n newrelic
```

**Resultado Esperado**:
```
NAME             NAMESPACE  REVISION  STATUS    CHART             APP VERSION
newrelic-bundle  newrelic   1         deployed  nri-bundle-5.x.x  x.x.x
```

**Verificar**:
- [ ] ✅ Release `newrelic-bundle` existe
- [ ] ✅ STATUS = `deployed`
- [ ] ✅ NAMESPACE = `newrelic`

Status detalhado:
```bash
helm status newrelic-bundle -n newrelic
```

- [ ] ✅ "STATUS: deployed"
- [ ] ✅ Sem erros na saída

### 6. Verificar Logs (Sampling)

Infrastructure Agent:
```bash
kubectl logs -n newrelic -l app.kubernetes.io/name=newrelic-infrastructure --tail=50 | grep -i "success\|error"
```

**Procurar por**:
- [ ] ✅ "Successfully sent metrics to New Relic"
- [ ] ✅ "Connected to New Relic"
- [ ] ❌ Sem "Error" ou "Failed"

FluentBit (se logging habilitado):
```bash
kubectl logs -n newrelic -l app.kubernetes.io/name=fluent-bit --tail=50 | grep -i "success\|error"
```

- [ ] ✅ Logs sendo coletados
- [ ] ❌ Sem erros críticos

### 7. Verificar Services

Execute:
```bash
kubectl get svc -n newrelic
```

**Resultado Esperado**:
```
NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
newrelic-kube-state-metrics       ClusterIP   10.100.xxx.xxx   <none>        8080/TCP   5m
```

- [ ] ✅ Services criados
- [ ] ✅ TYPE apropriado (ClusterIP)

### 8. Verificar ConfigMaps e Secrets

Execute:
```bash
kubectl get configmap -n newrelic
kubectl get secret -n newrelic
```

**Verificar**:
- [ ] ✅ ConfigMaps criados (3-5)
- [ ] ✅ Secrets criados (2-3)

Validar License Key (opcional):
```bash
kubectl get secret -n newrelic newrelic-bundle-newrelic-infrastructure-config -o jsonpath='{.data.license}' | base64 -d
```

- [ ] ✅ License key correta exibida

### 9. Verificar RBAC

Execute:
```bash
kubectl get serviceaccount -n newrelic
kubectl get clusterrole | grep newrelic
kubectl get clusterrolebinding | grep newrelic
```

**Verificar**:
- [ ] ✅ ServiceAccounts criados (5+)
- [ ] ✅ ClusterRoles criados (5+)
- [ ] ✅ ClusterRoleBindings criados (5+)

### 10. Testar Resource Usage

Execute:
```bash
kubectl top nodes
kubectl top pods -n newrelic
```

**Verificar**:
- [ ] ✅ Nodes com CPU < 80%
- [ ] ✅ Nodes com Memory < 80%
- [ ] ✅ Pods New Relic consumindo recursos esperados:
  - Infrastructure: ~100-200m CPU, ~150-250Mi Memory
  - FluentBit: ~100-300m CPU, ~128-200Mi Memory

---

## 🔔 Pós-Deployment: New Relic

### 1. Acessar Dashboard

Obter URL:
```bash
terraform output newrelic_dashboard_url
```

Abrir URL no navegador e fazer login.

**Verificar**:
- [ ] ✅ Dashboard carrega sem erros
- [ ] ✅ Nome: "Tech Challenge - EKS Cluster"
- [ ] ✅ 4 páginas visíveis:
  - [ ] Cluster Overview
  - [ ] Pods & Containers
  - [ ] Deployments & Services
  - [ ] Storage

### 2. Verificar Widgets na Página 1 (Cluster Overview)

**Verificar cada widget mostra dados**:
- [ ] ✅ Cluster Status (nodes, CPU, memory)
- [ ] ✅ Node CPU Usage (gráfico de linha)
- [ ] ✅ Node Memory Usage (gráfico de linha)
- [ ] ✅ Pods by Namespace (gráfico de barra)
- [ ] ✅ Pod Status Distribution (pizza)
- [ ] ✅ Container Restarts (linha)
- [ ] ✅ Network RX (área)
- [ ] ✅ Network TX (área)

### 3. Verificar Páginas 2, 3 e 4

**Página 2: Pods & Containers**
- [ ] ✅ Top Pods by CPU (tabela)
- [ ] ✅ Top Pods by Memory (tabela)
- [ ] ✅ Container CPU by Namespace (área)
- [ ] ✅ Container Memory by Namespace (área)
- [ ] ✅ CPU Throttling (linha)
- [ ] ✅ Filesystem Usage (barra)

**Página 3: Deployments & Services**
- [ ] ✅ Deployment Status (tabela)
- [ ] ✅ Replica Availability (linha)
- [ ] ✅ Services Count (billboard)
- [ ] ✅ Recent Events (tabela)

**Página 4: Storage**
- [ ] ✅ PV Status (pizza)
- [ ] ✅ PVC Status (pizza)
- [ ] ✅ Storage Classes (barra)
- [ ] ✅ Volume Usage (linha)

**Se widgets estiverem vazios**:
- Aguardar 2-5 minutos (delay normal)
- Verificar se pods estão enviando dados (ver logs)

### 4. Verificar Kubernetes Explorer

Acessar: https://one.newrelic.com/kubernetes

**Verificar**:
- [ ] ✅ Cluster `tech-challenge-cluster` aparece na lista
- [ ] ✅ Cluster status = "Connected"
- [ ] ✅ Número de nodes correto
- [ ] ✅ Consegue clicar no cluster e ver detalhes

**Dentro do Cluster**:
- [ ] ✅ Nodes aparecem
- [ ] ✅ Pods aparecem
- [ ] ✅ Deployments aparecem
- [ ] ✅ Services aparecem
- [ ] ✅ Consegue ver métricas ao clicar em cada objeto

### 5. Verificar Data via Query Builder

Acessar: https://one.newrelic.com/data-explorer

**Query 1: Verificar Nodes**
```sql
FROM K8sNodeSample SELECT count(*) WHERE clusterName = 'tech-challenge-cluster'
```

- [ ] ✅ Retorna número de nodes (default: 2)

**Query 2: Verificar Pods**
```sql
FROM K8sPodSample SELECT uniqueCount(podName) WHERE clusterName = 'tech-challenge-cluster' SINCE 5 minutes ago
```

- [ ] ✅ Retorna número > 0

**Query 3: Verificar Eventos**
```sql
FROM InfrastructureEvent SELECT count(*) WHERE category = 'kubernetes' AND clusterName = 'tech-challenge-cluster' SINCE 1 hour ago
```

- [ ] ✅ Retorna eventos > 0

**Query 4: Verificar Logs (se logging habilitado)**
```sql
FROM Log SELECT count(*) WHERE kubernetes.cluster_name = 'tech-challenge-cluster' SINCE 5 minutes ago
```

- [ ] ✅ Retorna logs > 0

### 6. Verificar Alert Policy

Acessar: https://one.newrelic.com/alerts-ai/condition-builder

Ou obter ID:
```bash
terraform output newrelic_alert_policy_id
```

**Verificar**:
- [ ] ✅ Policy "EKS Cluster Alerts - tech-challenge-cluster" existe
- [ ] ✅ Status = "Enabled"
- [ ] ✅ 8 condições criadas:
  - [ ] High Node CPU Usage
  - [ ] High Node Memory Usage
  - [ ] Node Not Ready
  - [ ] High Pod CPU Usage
  - [ ] High Pod Memory Usage
  - [ ] Pod Restart Loop
  - [ ] High CPU Throttling
  - [ ] Deployment Replica Mismatch

**Para cada condição**:
- [ ] ✅ Status = "Enabled"
- [ ] ✅ NRQL query configurada
- [ ] ✅ Threshold configurado

### 7. Verificar Notification Channel

**Acessar**: Administration > Notification channels

**Verificar**:
- [ ] ✅ Canal de email existe
- [ ] ✅ Destination: Email configurado
- [ ] ✅ Status = "Connected"

### 8. Verificar Workflow

**Acessar**: Alerts & AI > Workflows

**Verificar**:
- [ ] ✅ Workflow "EKS Alerts Email Workflow" existe
- [ ] ✅ Status = "Enabled"
- [ ] ✅ Conectado à policy de alertas
- [ ] ✅ Email destination configurado

### 9. Testar Alerta (Opcional)

**⚠️ CUIDADO: Isso criará um pod stress no cluster**

Criar pod de teste:
```bash
kubectl run stress-test --image=polinux/stress --restart=Never -- stress --cpu 2 --timeout 300s
```

**Aguardar**:
- 5 minutos para threshold ser atingido
- Email de alerta chegar

**Verificar**:
- [ ] ✅ Alerta "High Pod CPU Usage" triggered
- [ ] ✅ Email recebido
- [ ] ✅ Email contém detalhes do alerta

**Cleanup**:
```bash
kubectl delete pod stress-test
```

---

## 📊 Verificação de Performance

### 1. Overhead de Recursos

**Cluster Usage**:
```bash
kubectl top nodes
```

- [ ] ✅ CPU total < 80%
- [ ] ✅ Memory total < 80%

**New Relic Pods**:
```bash
kubectl top pods -n newrelic
```

**Verificar uso por pod**:
- [ ] ✅ Infrastructure Agent: CPU ~100-200m, Memory ~150-250Mi
- [ ] ✅ FluentBit: CPU ~100-300m, Memory ~128-200Mi
- [ ] ✅ Kube-State-Metrics: CPU ~50-150m, Memory ~100-150Mi
- [ ] ✅ Events: CPU ~50-100m, Memory ~80-120Mi
- [ ] ✅ Prometheus: CPU ~50-150m, Memory ~100-150Mi

**Total overhead**:
- [ ] ✅ CPU total New Relic < 1 core (1000m)
- [ ] ✅ Memory total New Relic < 1 GB

### 2. Data Ingestion

**Verificar no New Relic**: Administration > Data management

**Métricas**:
- [ ] ✅ Data ingestion dentro do esperado (~100-200 MB/dia)
- [ ] ✅ Dentro do free tier (100 GB/mês)

---

## 🔒 Verificação de Segurança

### 1. Secrets

Verificar que secrets não estão expostos:
```bash
# Não deve mostrar valores em plain text
kubectl get secret -n newrelic newrelic-bundle-newrelic-infrastructure-config -o yaml
```

- [ ] ✅ Valores em base64
- [ ] ✅ License key não exposta em plain text

### 2. RBAC

Verificar permissões:
```bash
kubectl get clusterrolebinding newrelic -o yaml
```

- [ ] ✅ Permissões limitadas ao necessário
- [ ] ✅ Sem `cluster-admin` binding

### 3. Network

Verificar se pods conseguem acessar New Relic:
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- https://metric-api.newrelic.com/health
```

- [ ] ✅ Retorna HTTP 200 OK
- [ ] ✅ Conectividade com New Relic funcionando

---

## ✅ Checklist Final

### Infraestrutura
- [ ] ✅ EKS Cluster criado e acessível
- [ ] ✅ Nodes em estado Ready
- [ ] ✅ VPC e networking funcionando
- [ ] ✅ kubectl configurado

### New Relic Integration
- [ ] ✅ Namespace newrelic criado
- [ ] ✅ Todos os pods Running
- [ ] ✅ Helm release deployed
- [ ] ✅ Logs sem erros
- [ ] ✅ Métricas sendo enviadas

### Observabilidade
- [ ] ✅ Dashboard acessível e populado
- [ ] ✅ 22 widgets com dados
- [ ] ✅ Kubernetes Explorer funcionando
- [ ] ✅ Query Builder retornando dados
- [ ] ✅ 8 alertas configurados
- [ ] ✅ Email notifications configuradas

### Performance
- [ ] ✅ Overhead de recursos aceitável (<20%)
- [ ] ✅ Data ingestion dentro do esperado
- [ ] ✅ Sem degradação de performance

### Segurança
- [ ] ✅ Secrets protegidas
- [ ] ✅ RBAC configurado
- [ ] ✅ Network connectivity segura

---

## 🎯 Score Final

**Marque quantos itens você completou**:

- **Pré-Deployment**: ___/10
- **Durante Deployment**: ___/20
- **Kubernetes**: ___/35
- **New Relic**: ___/40
- **Performance**: ___/10
- **Segurança**: ___/5

**Total**: ___/120

### Interpretação

- **120/120 (100%)**: ✅ **PERFEITO** - Deployment completo e validado
- **110-119 (91-99%)**: ✅ **EXCELENTE** - Deployment bem-sucedido com itens menores pendentes
- **100-109 (83-90%)**: ⚠️ **BOM** - Deployment funcional mas requer ajustes
- **< 100 (<83%)**: ❌ **INCOMPLETO** - Verificar troubleshooting

---

## 🆘 Troubleshooting

### Problema: Pods em CrashLoopBackOff

**Diagnóstico**:
```bash
kubectl describe pod -n newrelic <pod-name>
kubectl logs -n newrelic <pod-name>
```

**Soluções Comuns**:
1. License key inválida → Atualizar terraform.tfvars
2. Permissões RBAC → Reinstalar Helm chart
3. Resource limits → Ajustar em newrelic.tf

### Problema: Dashboard vazio

**Soluções**:
1. Aguardar 5 minutos (delay normal)
2. Verificar logs dos pods
3. Testar query no Query Builder
4. Verificar Account ID e região

### Problema: Alertas não disparando

**Soluções**:
1. Verificar email configurado
2. Verificar workflow enabled
3. Testar query NRQL no Query Builder
4. Verificar threshold não atingido

### Problema: kubectl não conecta

**Soluções**:
```bash
# Reconfigurar kubeconfig
aws eks update-kubeconfig --name tech-challenge-cluster --region us-east-1 --force

# Verificar AWS credentials
aws sts get-caller-identity

# Verificar cluster existe
aws eks describe-cluster --name tech-challenge-cluster
```

### Problema: High Resource Usage

**Soluções**:
1. Reduzir intervalo de coleta (15s → 30s)
2. Desabilitar logging temporariamente
3. Ajustar resource limits
4. Scale up nodes

---

## 📞 Suporte

### Documentação Interna
- 📄 [README.md](README.md)
- 📄 [NEW_RELIC_EKS_INFRASTRUCTURE.md](NEW_RELIC_EKS_INFRASTRUCTURE.md)
- 📄 [QUICK_START.md](QUICK_START.md)

### Documentação Externa
- 🌐 [New Relic Kubernetes Integration](https://docs.newrelic.com/docs/kubernetes-pixie/kubernetes-integration/get-started/introduction-kubernetes-integration/)
- 🌐 [AWS EKS Troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- 🌐 [Helm Docs](https://helm.sh/docs/)

---

**Checklist Version**: 1.0.0  
**Last Updated**: Janeiro 2026  
**Status**: ✅ Ready for use
