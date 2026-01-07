# Quick Start - New Relic EKS Observability

> Deploy completo de EKS com observabilidade New Relic em 15 minutos ⏱️

[![Terraform](https://img.shields.io/badge/Time-15_minutes-blue)](https://www.terraform.io/)
[![New Relic](https://img.shields.io/badge/Difficulty-Easy-green)](https://newrelic.com/)

---

## ⏱️ Timeline

- **5 min**: Obter credenciais New Relic
- **3 min**: Configurar variáveis Terraform
- **10 min**: Deploy da infraestrutura
- **2 min**: Verificar instalação
- **Total**: **20 minutos**

---

## 📋 Pré-requisitos

Antes de começar, você precisa ter instalado:

```bash
# Verificar versões
terraform version   # >= 1.2.0
aws --version      # >= 2.0
kubectl version    # >= 1.27
helm version       # >= 3.0
```

Se não tiver instalado:

### Windows (PowerShell)
```powershell
# Chocolatey
choco install terraform awscli kubernetes-cli kubernetes-helm

# Winget
winget install Hashicorp.Terraform
winget install Amazon.AWSCLI
winget install Kubernetes.kubectl
winget install Helm.Helm
```

### macOS
```bash
brew install terraform awscli kubectl helm
```

### Linux
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y terraform awscli kubectl helm

# CentOS/RHEL
sudo yum install -y terraform awscli kubectl helm
```

---

## 🚀 Passo a Passo

### Passo 1: Obter Credenciais New Relic (5 min)

#### 1.1 Login no New Relic
```
https://one.newrelic.com
```

#### 1.2 Obter Account ID
1. Click no seu nome (canto superior direito)
2. **Administration** → **Access management** → **API keys**
3. Copiar **Account ID** (7 dígitos, exemplo: `1234567`)

#### 1.3 Criar User API Key (para Terraform)
1. Ainda em **API keys**, click **Create a key**
2. **Key type**: User key
3. **Name**: `terraform-eks-infrastructure`
4. Click **Create a key**
5. Copiar a chave (começa com `NRAK-`)
6. ⚠️ Guardar em lugar seguro (não será mostrada novamente)

#### 1.4 Obter License Key (para agentes)
1. Click no seu nome → **Administration** → **API keys**
2. Tab **License keys**
3. Copiar **License key** (para região EU começa com `euXXXXNRAL`, US começa com `NRAL`)

**Resultado**:
```
✅ Account ID: 1234567
✅ User API Key: NRAK-XXXXXXXXXXXXXXXXXXXX
✅ License Key: euXXXXNRAL (ou NRAL)
```

---

### Passo 2: Configurar AWS Credentials (2 min)

#### 2.1 Configurar AWS CLI

```bash
aws configure
```

Fornecer:
```
AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name: us-east-1
Default output format: json
```

#### 2.2 Testar Conectividade

```bash
aws sts get-caller-identity
```

Deve retornar:
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

### Passo 3: Clonar e Configurar (3 min)

#### 3.1 Navegar para o Diretório

```bash
cd tech_challenge_k8s_infra
```

#### 3.2 Copiar Exemplo de Configuração

```bash
cp terraform.tfvars.example terraform.tfvars
```

#### 3.3 Editar terraform.tfvars

**Windows**:
```powershell
notepad terraform.tfvars
```

**macOS/Linux**:
```bash
nano terraform.tfvars
# ou
vim terraform.tfvars
```

#### 3.4 Configurar Variáveis Obrigatórias

**Mínimo necessário**:
```hcl
# New Relic
newrelic_account_id  = "1234567"                      # SEU account ID
newrelic_api_key     = "NRAK-XXXXXXXXXXXXXXXXXXXXX"   # SEU User API Key
newrelic_license_key = "euXXXXNRAL"                   # SEU License Key
newrelic_region      = "EU"                           # "US" ou "EU"
alert_email          = "your-team@example.com"        # SEU email

# AWS
aws_region = "us-east-1"                              # Região desejada

# EKS
cluster_name = "tech-challenge-cluster"               # Nome do cluster
```

**Configuração completa (opcional)**:
```hcl
# Adicionar ao arquivo acima:

# Node Group
node_instance_type = "t3.small"     # t3.small, t3.medium, t3.large
desired_capacity   = 2              # Número de nodes
min_capacity       = 1
max_capacity       = 3

# Observabilidade
enable_newrelic_monitoring = true   # Habilitar monitoring
enable_logging            = true    # Habilitar logs

# Alertas (thresholds)
alert_node_cpu_threshold    = 80    # Alerta se node CPU > 80%
alert_node_memory_threshold = 80    # Alerta se node memory > 80%
alert_pod_cpu_threshold     = 90    # Alerta se pod CPU > 90%
alert_pod_memory_threshold  = 90    # Alerta se pod memory > 90%

# Ambiente
environment = "dev"                 # dev, staging, prod
```

**Salvar e fechar** (Ctrl+S, Ctrl+X no nano).

---

### Passo 4: Deploy (10 min)

#### 4.1 Inicializar Terraform

```bash
terraform init
```

**Saída esperada**:
```
Initializing the backend...
Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Finding latest version of newrelic/newrelic...
- Finding latest version of hashicorp/helm...
- Finding latest version of hashicorp/kubernetes...
- Installing...

Terraform has been successfully initialized!
```

#### 4.2 Revisar Plano

```bash
terraform plan
```

**Verificar**:
- Resources a serem criados: ~40-50
- EKS cluster será criado
- VPC e subnets serão criadas
- New Relic será configurado

#### 4.3 Aplicar Infraestrutura

```bash
terraform apply
```

**Confirmar**:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

**Aguardar**: ~8-10 minutos

**Saída esperada**:
```
Apply complete! Resources: 45 added, 0 changed, 0 destroyed.

Outputs:

cluster_endpoint = "https://XXXXX.gr7.us-east-1.eks.amazonaws.com"
cluster_name = "tech-challenge-cluster"
newrelic_dashboard_url = "https://one.newrelic.com/dashboards/XXXXXX"
newrelic_alert_policy_id = "1234567"
```

---

### Passo 5: Configurar kubectl (2 min)

#### 5.1 Atualizar kubeconfig

```bash
aws eks update-kubeconfig --name tech-challenge-cluster --region us-east-1
```

**Saída**:
```
Added new context arn:aws:eks:us-east-1:123456789012:cluster/tech-challenge-cluster to /Users/you/.kube/config
```

#### 5.2 Verificar Nodes

```bash
kubectl get nodes
```

**Saída esperada**:
```
NAME                             STATUS   ROLES    AGE   VERSION
ip-10-0-1-123.ec2.internal       Ready    <none>   2m    v1.29.0
ip-10-0-2-234.ec2.internal       Ready    <none>   2m    v1.29.0
```

✅ **Nodes estão Ready!**

---

### Passo 6: Verificar New Relic (2 min)

#### 6.1 Ver Pods do New Relic

```bash
kubectl get pods -n newrelic
```

**Saída esperada**:
```
NAME                                       READY   STATUS    RESTARTS   AGE
newrelic-infrastructure-abc123             1/1     Running   0          3m
newrelic-infrastructure-def456             1/1     Running   0          3m
newrelic-kube-state-metrics-xxx            1/1     Running   0          3m
newrelic-fluent-bit-ghi789                 1/1     Running   0          3m
newrelic-fluent-bit-jkl012                 1/1     Running   0          3m
```

✅ **Todos os pods Running!**

#### 6.2 Verificar Logs (opcional)

```bash
kubectl logs -n newrelic -l app.kubernetes.io/name=newrelic-infrastructure --tail=20
```

**Procurar por**:
```
[INFO] Successfully sent metrics to New Relic
[INFO] Connected to New Relic platform
```

#### 6.3 Ver Dashboard URL

```bash
terraform output newrelic_dashboard_url
```

**Copiar URL** e abrir no navegador.

#### 6.4 Acessar Dashboard

1. Abrir URL do output anterior
2. Login no New Relic (se necessário)
3. Ver dashboard com 4 páginas:
   - **Cluster Overview**: Status geral, CPU, Memory
   - **Pods & Containers**: Top consumers, throttling
   - **Deployments & Services**: Replica status, events
   - **Storage**: PV/PVC status

✅ **Dashboard funcionando!**

---

## ✅ Checklist de Verificação

Após o deploy, verificar:

### Infraestrutura AWS

```bash
# EKS Cluster
aws eks describe-cluster --name tech-challenge-cluster --query 'cluster.status'
# Deve retornar: "ACTIVE"

# Nodes
kubectl get nodes
# Deve mostrar nodes em "Ready"

# VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=tech-challenge-vpc" --query 'Vpcs[0].State'
# Deve retornar: "available"
```

### New Relic Integration

```bash
# Pods rodando
kubectl get pods -n newrelic --field-selector=status.phase=Running | wc -l
# Deve retornar: 5-7 (dependendo do número de nodes)

# Helm release
helm list -n newrelic
# Deve mostrar: newrelic-bundle DEPLOYED

# License key configurada
kubectl get secret -n newrelic | grep newrelic
# Deve mostrar secrets criadas
```

### Métricas no New Relic

1. **Kubernetes Explorer**:
   - Acessar: https://one.newrelic.com/kubernetes
   - Selecionar cluster: `tech-challenge-cluster`
   - Ver nodes, pods, containers

2. **Dashboard Custom**:
   - Usar URL do output `newrelic_dashboard_url`
   - Ver widgets com dados

3. **Query Builder**:
   ```sql
   FROM K8sNodeSample SELECT count(*) WHERE clusterName = 'tech-challenge-cluster'
   ```
   - Deve retornar: Número de nodes

### Alertas

```bash
# Ver política criada
terraform output newrelic_alert_policy_id

# Testar alerta (opcional - cuidado!)
kubectl run stress --image=polinux/stress --restart=Never -- stress --cpu 2
# Aguardar 5 minutos, verificar email
kubectl delete pod stress
```

---

## 🎯 Próximos Passos

### 1. Deploy de Aplicação de Teste

```bash
# Criar deployment de teste
kubectl create deployment nginx --image=nginx:latest
kubectl scale deployment nginx --replicas=3
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Ver no New Relic
# Aguardar 2-3 minutos e verificar dashboard
```

### 2. Configurar HPA (Horizontal Pod Autoscaler)

```bash
kubectl autoscale deployment nginx --cpu-percent=50 --min=1 --max=10

# Ver HPA
kubectl get hpa
```

### 3. Configurar Ingress (opcional)

```bash
# Instalar NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

# Configurar ingress para sua aplicação
```

### 4. Configurar CI/CD

- GitHub Actions para deploy automático
- ArgoCD para GitOps
- Flux CD

### 5. Explorar New Relic

- **Kubernetes Explorer**: Ver topology do cluster
- **Distributed Tracing**: Adicionar APM em apps
- **Logs**: Pesquisar e filtrar logs
- **Alertas**: Customizar thresholds
- **Dashboards**: Criar dashboards personalizados

---

## 🔧 Comandos Úteis

### Terraform

```bash
# Ver outputs
terraform output

# Ver state
terraform state list

# Refresh outputs
terraform refresh

# Destruir (CUIDADO!)
terraform destroy
```

### Kubernetes

```bash
# Contexts
kubectl config get-contexts
kubectl config use-context <context-name>

# Namespaces
kubectl get namespaces

# Pods em todos namespaces
kubectl get pods --all-namespaces

# Recursos de node
kubectl top nodes
kubectl top pods --all-namespaces

# Eventos
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Port forward para um pod
kubectl port-forward -n <namespace> <pod-name> 8080:80
```

### Helm

```bash
# Listar releases
helm list --all-namespaces

# Status de um release
helm status newrelic-bundle -n newrelic

# Ver valores configurados
helm get values newrelic-bundle -n newrelic

# Upgrade (se necessário)
helm upgrade newrelic-bundle newrelic/nri-bundle -n newrelic
```

### AWS

```bash
# Listar clusters
aws eks list-clusters

# Descrever cluster
aws eks describe-cluster --name tech-challenge-cluster

# Listar nodes
aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/tech-challenge-cluster,Values=owned" --query 'Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress]' --output table

# Listar VPCs
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=tech-challenge-vpc"
```

---

## ❓ FAQ

### P: Quanto tempo leva o deploy completo?
**R**: Aproximadamente 10-15 minutos para criar todo o cluster EKS e configurar New Relic.

### P: Quanto custa?
**R**: 
- **AWS**: ~$140/mês (dev) a ~$280/mês (prod)
- **New Relic**: $0 (free tier 100GB/mês)
- **Total**: ~$140-280/mês

### P: Posso usar em produção?
**R**: Sim! Esta configuração é production-ready, mas considere:
- Aumentar node instance type (t3.medium ou maior)
- Aumentar número de nodes (min=2, desired=3)
- Habilitar multi-AZ (já configurado)
- Configurar backup/disaster recovery
- Implementar network policies

### P: Como faço upgrade do cluster?
**R**: 
```hcl
# Em variables.tf ou terraform.tfvars
cluster_version = "1.30"  # Atualizar versão

# Aplicar
terraform plan
terraform apply
```

### P: Como adiciono mais nodes?
**R**:
```hcl
# Em terraform.tfvars
desired_capacity = 3  # Aumentar
max_capacity     = 5  # Aumentar

# Aplicar
terraform apply
```

### P: New Relic free tier é suficiente?
**R**: Sim! Para clusters pequenos/médios (até ~10 nodes, 50-100 pods), o free tier de 100GB/mês é mais que suficiente.

### P: Como desabilito logging temporariamente?
**R**:
```hcl
# terraform.tfvars
enable_logging = false

# Aplicar
terraform apply
```

### P: Posso usar múltiplos clusters?
**R**: Sim! Cada cluster terá seu próprio dashboard. Basta deploy com `cluster_name` diferente.

### P: Como rotaciono credenciais New Relic?
**R**:
1. Criar novo User API Key no New Relic
2. Atualizar `newrelic_api_key` em terraform.tfvars
3. Executar `terraform apply`

---

## 🆘 Troubleshooting

### Erro: "Error creating cluster"

**Causa**: Quota AWS insuficiente ou permissões IAM.

**Solução**:
```bash
# Verificar quota
aws service-quotas get-service-quota --service-code eks --quota-code L-1194D53C

# Verificar permissões
aws iam get-user
```

### Erro: "Pods NewRelic em CrashLoopBackOff"

**Causa**: License key inválida.

**Solução**:
```bash
# Verificar license key
kubectl get secret -n newrelic newrelic-bundle-newrelic-infrastructure-config -o jsonpath='{.data.license}' | base64 -d

# Se incorreta, atualizar terraform.tfvars e aplicar
terraform apply -replace='helm_release.newrelic_bundle[0]'
```

### Erro: "Dashboard vazio"

**Causa**: Métricas ainda não foram enviadas (leva 2-5 min).

**Solução**:
```bash
# Aguardar 5 minutos e verificar logs
kubectl logs -n newrelic -l app.kubernetes.io/name=newrelic-infrastructure | grep "sent"

# Deve mostrar: "Successfully sent metrics"
```

### Erro: "kubectl: connection refused"

**Causa**: kubeconfig não atualizado.

**Solução**:
```bash
aws eks update-kubeconfig --name tech-challenge-cluster --region us-east-1 --force
```

---

## 📚 Documentação Adicional

- 📄 [README.md](README.md) - Visão geral completa
- 📄 [NEW_RELIC_EKS_INFRASTRUCTURE.md](NEW_RELIC_EKS_INFRASTRUCTURE.md) - Documentação técnica detalhada
- 📄 [terraform.tfvars.example](terraform.tfvars.example) - Exemplo completo de configuração
- 🌐 [New Relic Kubernetes Docs](https://docs.newrelic.com/docs/kubernetes-pixie/kubernetes-integration/get-started/introduction-kubernetes-integration/)
- 🌐 [AWS EKS Docs](https://docs.aws.amazon.com/eks/)

---

## 🎉 Conclusão

Parabéns! Você agora tem:

✅ **EKS Cluster 1.29** rodando na AWS  
✅ **Observabilidade completa** com New Relic  
✅ **8 alertas críticos** configurados  
✅ **Dashboard customizado** com 20+ widgets  
✅ **Kubernetes Explorer** totalmente funcional  
✅ **Logging integration** com FluentBit  
✅ **Production-ready infrastructure**  

**Próximo passo**: Deploy sua aplicação e monitore tudo em tempo real! 🚀

---

**Version**: 1.0.0  
**Last Updated**: Janeiro 2026  
**Estimated Time**: ⏱️ 15-20 minutos  
**Difficulty**: 🟢 Easy
