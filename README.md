# Tech Challenge - Kubernetes Infrastructure

Este repositório contém a definição de Infraestrutura como Código (IaC) para o Cluster Kubernetes do projeto Tech Challenge.

## Tecnologias
- **Terraform:** Provisionamento da infraestrutura.
- **AWS EKS:** Serviço de Kubernetes gerenciado.
- **AWS VPC:** Rede privada virtual para o cluster.

## Estrutura
- `main.tf`: Configuração do provider AWS.
- `vpc.tf`: Definição da VPC, Subnets e Internet Gateway.
- `eks.tf`: Definição do Cluster EKS e Node Groups.
- `variables.tf`: Variáveis de configuração (nome do cluster, tipo de instância).
- `outputs.tf`: Outputs úteis (endpoint do cluster).

## Como Executar

1.  **Pré-requisitos:**
    - Terraform instalado.
    - Credenciais AWS configuradas.

2.  **Inicializar:**
    ```bash
    terraform init
    ```

3.  **Planejar:**
    ```bash
    terraform plan
    ```

4.  **Aplicar:**
    ```bash
    terraform apply
    ```

5.  **Configurar Kubectl:**
    Após a criação, configure o `kubectl` para acessar o cluster:
    ```bash
    aws eks update-kubeconfig --region us-east-1 --name tech-challenge-cluster
    ```
