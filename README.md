# Tech Challenge - Kubernetes Infrastructure

Este repositório contém **TODOS os manifestos Kubernetes** e configuração Terraform do cluster EKS para o Sistema de Gestão de Oficina.

## 🎯 Arquitetura

- **EKS Cluster**: Gerenciado via Terraform
- **3 Microserviços**: OS Service, Billing Service, Execution Service
- **Kustomize**: Gerenciamento de manifestos K8s
- **Observabilidade**: New Relic APM + Dashboards

## 📁 Estrutura

```
tech_challenge_k8s_infra/
├── # Terraform (Infraestrutura EKS)
├── main.tf                 # Providers (AWS, Helm, Kubernetes, New Relic)
├── eks.tf                  # Cluster EKS
├── vpc.tf                  # VPC para EKS
├── app_config.tf           # ConfigMaps para apps
├── newrelic.tf             # New Relic integration
├── dashboards.tf           # Dashboards customizados
├── variables.tf            # Variáveis Terraform
├── outputs.tf              # Outputs do cluster
├── backend.tf              # Terraform state
│
├── # Kubernetes (Manifestos dos Microserviços)
├── kustomization.yaml      # ⭐ Deploy ALL services at once
│
└── microservices/
    ├── os-service/         # OS Service K8s manifests
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── ingress.yaml
    │   ├── hpa.yaml
    │   ├── configmap.yaml
    │   └── secret.yaml
    │
    ├── billing-service/    # Billing Service K8s manifests
    │   └── ... (mesma estrutura)
    │
    └── execution-service/  # Execution Service K8s manifests
        └── ... (mesma estrutura)
```

## 🚀 Workflow Completo

### Passo 1: Provisionar Bancos de Dados

Primeiro, provisione os bancos RDS no repositório `tech_challenge_db_infra`:

```bash
cd ../tech_challenge_db_infra
terraform init
terraform apply
terraform output  # Anote os endpoints dos bancos
```

### Passo 2: Provisionar Cluster EKS

```bash
cd ../tech_challenge_k8s_infra

# Configurar variáveis (crie terraform.tfvars)
cat > terraform.tfvars <<EOF
aws_region         = "us-east-1"
cluster_name       = "oficina-eks-cluster"
node_instance_type = "t3.medium"
desired_capacity   = 2
newrelic_account_id = "YOUR_ACCOUNT_ID"
newrelic_api_key    = "YOUR_API_KEY"
EOF

# Provisionar EKS
terraform init
terraform apply
```

### Passo 3: Configurar kubectl

```bash
# Configurar kubectl para acessar o cluster
aws eks update-kubeconfig --region us-east-1 --name oficina-eks-cluster

# Verificar conexão
kubectl get nodes
```

### Passo 4: Atualizar ConfigMaps com Endpoints dos Bancos

Edite os ConfigMaps de cada microserviço com os endpoints obtidos no Passo 1:

```bash
# Exemplo: microservices/os-service/configmap.yaml
nano microservices/os-service/configmap.yaml

# Atualizar DB_HOST com o endpoint do RDS
# DB_HOST: "os-service-db.xxxxxx.us-east-1.rds.amazonaws.com"
```

Repita para `billing-service` e `execution-service`.

### Passo 5: Atualizar Secrets

```bash
# Encode credenciais em base64
echo -n "os_service_user" | base64
echo -n "SuaSenhaSegura123!" | base64

# Editar microservices/os-service/secret.yaml com os valores encodados
```

⚠️ **Produção**: Use [External Secrets Operator](https://external-secrets.io/) ou AWS Secrets Manager.

### Passo 6: Deploy dos Microserviços

#### Opção A: Deploy TODOS os serviços de uma vez

```bash
kubectl apply -k .
```

#### Opção B: Deploy serviço por serviço

```bash
# OS Service
kubectl apply -k microservices/os-service/

# Billing Service
kubectl apply -k microservices/billing-service/

# Execution Service
kubectl apply -k microservices/execution-service/
```

### Passo 7: Verificar Deploy

```bash
# Verificar pods
kubectl get pods -n os-service
kubectl get pods -n billing-service
kubectl get pods -n execution-service

# Verificar serviços
kubectl get svc --all-namespaces

# Verificar ingress
kubectl get ingress --all-namespaces

# Logs de um pod
kubectl logs -n os-service deployment/os-service -f
```

## 📊 Monitoramento

### New Relic

Após o deploy, acesse o New Relic:
- **APM**: Monitora performance dos microserviços
- **Dashboards**: Visualizações customizadas de métricas
- **Alerts**: Configurados via Terraform

### Kubernetes Dashboard

```bash
# Instalar dashboard (opcional)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Criar token de acesso
kubectl -n kubernetes-dashboard create token admin-user
```

## 🔧 Operações Comuns

### Escalar Deployment

```bash
kubectl scale deployment os-service -n os-service --replicas=3
```

### Ver Métricas HPA

```bash
kubectl get hpa -n os-service
```

### Atualizar Imagem

```bash
# Via Kustomize (editar kustomization.yaml)
images:
  - name: os-service
    newTag: v1.2.0

kubectl apply -k microservices/os-service/

# Ou direto
kubectl set image deployment/os-service os-service=<ECR_URI>:v1.2.0 -n os-service
```

### Rollback

```bash
kubectl rollout undo deployment/os-service -n os-service
kubectl rollout history deployment/os-service -n os-service
```

### Port Forward (para testes locais)

```bash
kubectl port-forward -n os-service svc/os-service 8081:8081
# Acesse http://localhost:8081
```

## 🔐 Segurança

### Produção (Recomendado)

1. **Secrets Management**:
   ```bash
   # Instalar External Secrets Operator
   helm repo add external-secrets https://charts.external-secrets.io
   helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
   ```

2. **Network Policies**: Restringir comunicação entre pods

3. **Pod Security Standards**: Configurar PSS no namespace

4. **RBAC**: Limitar permissões de service accounts

5. **Ingress TLS**: Configurar certificados SSL via Cert Manager

## 🗑️ Destruir Infraestrutura

```bash
# 1. Deletar microserviços
kubectl delete -k .

# 2. Destruir EKS cluster
terraform destroy

# 3. Destruir bancos de dados (em tech_challenge_db_infra)
cd ../tech_challenge_db_infra
terraform destroy
```

## 📚 Documentação Detalhada

- [microservices/README.md](./microservices/README.md) - Deploy individual de serviços
- [Kustomize Docs](https://kustomize.io/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## 🆘 Troubleshooting

### Pods em CrashLoopBackOff

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

**Causas comuns**:
- Endpoint do banco incorreto no ConfigMap
- Credenciais inválidas no Secret
- Variáveis de ambiente faltando

### ImagePullBackOff

```bash
kubectl describe pod <pod-name> -n <namespace>
```

**Soluções**:
- Verificar se imagem existe no ECR
- Configurar ImagePullSecrets para ECR
- Verificar permissões IAM do node

### Service não acessível

```bash
# Verificar endpoints
kubectl get endpoints -n <namespace>

# Verificar selector do service
kubectl get svc <service-name> -n <namespace> -o yaml
```

## 🔄 CI/CD

Para automatizar deploys:

```yaml
# GitHub Actions exemplo
name: Deploy to EKS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name oficina-eks-cluster
      
      - name: Deploy to EKS
        run: kubectl apply -k .
```

## 📞 Suporte

Para questões sobre Kubernetes/EKS:
- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kustomize Tutorial](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/)
