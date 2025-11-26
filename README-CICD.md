# CI/CD - EKS Infrastructure

Este repositório utiliza GitHub Actions para deploy automatizado da infraestrutura EKS.

## 🔧 Configuração Inicial

### 1. Secrets do GitHub

Configure os seguintes secrets no repositório GitHub:

```
Settings → Secrets and variables → Actions → New repository secret
```

**Secrets necessários:**
- `AWS_ACCESS_KEY_ID` - Access Key da AWS
- `AWS_SECRET_ACCESS_KEY` - Secret Key da AWS

### 2. Proteção de Branches

Configure proteção na branch `main`:

```
Settings → Branches → Add branch protection rule
```

**Regras obrigatórias:**
- ✅ Require a pull request before merging
- ✅ Require approvals (mínimo 1)
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging

## 🚀 Fluxo de Deploy

### Deploy Automático (Main Branch)

```bash
# 1. Criar nova branch
git checkout -b feature/ajuste-eks

# 2. Fazer alterações
# Editar arquivos .tf conforme necessário

# 3. Commit e push
git add .
git commit -m "feat: ajuste configuração EKS"
git push origin feature/ajuste-eks

# 4. Criar Pull Request no GitHub
# O workflow irá executar: terraform plan

# 5. Após aprovação e merge para main
# O workflow irá executar: terraform apply
```

### Workflow Executado

```yaml
PR → Terraform Format Check
  → Terraform Init
  → Terraform Validate
  → Terraform Plan (comentado no PR)

Merge → Terraform Apply
      → Configure kubectl
      → Verify cluster
      → Outputs armazenados no SSM Parameter Store
```

## 📊 Outputs

Após o deploy, os seguintes valores são armazenados no AWS SSM:

- `/oficina/eks/cluster_name` - Nome do cluster EKS
- `/oficina/eks/cluster_endpoint` - Endpoint da API do cluster
- `/oficina/eks/region` - Região AWS

## 🔍 Verificação Manual

```bash
# Configurar kubectl local
CLUSTER_NAME=$(aws ssm get-parameter --name /oficina/eks/cluster_name --query Parameter.Value --output text)
REGION=$(aws ssm get-parameter --name /oficina/eks/region --query Parameter.Value --output text)

aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verificar nodes
kubectl get nodes

# Verificar cluster info
kubectl cluster-info
```

## ⚙️ Recursos Criados

Este Terraform provisiona:

- ✅ VPC com subnets públicas e privadas
- ✅ NAT Gateway para conectividade
- ✅ Cluster EKS (Kubernetes 1.29)
- ✅ Node Group gerenciado (2 nodes t3.small)
- ✅ Auto-scaling configurado (1-3 nodes)
- ✅ Security Groups configurados

## 💰 Estimativa de Custos

| Recurso | Tipo | Custo Mensal (us-east-1) |
|---------|------|--------------------------|
| EKS Cluster | - | ~$73 |
| EC2 Nodes | 2x t3.small | ~$30 |
| NAT Gateway | - | ~$32 |
| **TOTAL** | | **~$135/mês** |

> ⚠️ Custos podem variar. Use AWS Cost Explorer para monitoramento preciso.

## 🐛 Troubleshooting

### Erro: "Cluster already exists"
```bash
# Importar cluster existente
terraform import module.eks.aws_eks_cluster.this tech-challenge-cluster
```

### Erro: "Node group not ready"
```bash
# Verificar eventos do EKS
aws eks describe-cluster --name tech-challenge-cluster

# Verificar node group
aws eks describe-nodegroup \
  --cluster-name tech-challenge-cluster \
  --nodegroup-name default_node_group
```

### Erro: "kubectl: connection refused"
```bash
# Re-configurar kubectl
aws eks update-kubeconfig \
  --region us-east-1 \
  --name tech-challenge-cluster

# Verificar contexto
kubectl config current-context
```

## 🔐 Boas Práticas de Segurança

1. **NUNCA commite credenciais AWS** no código
2. Use **IAM Roles** ao invés de Access Keys quando possível
3. Habilite **Audit Logs** no EKS para compliance
4. Configure **Network Policies** no Kubernetes
5. Use **Pod Security Standards** (PSS)

## 📚 Documentação Adicional

- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)