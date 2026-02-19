# Kafka Infrastructure - Saga Pattern

Infraestrutura centralizada do Apache Kafka para suporte à arquitetura de eventos (Event-Driven) com padrão Saga Coreografada.

## 📋 Componentes

### 1. Zookeeper
- **Deployment**: zookeeper-deployment.yaml
- **Service**: zookeeper-service.yaml
- **Purpose**: Coordenação e consenso distribuído do cluster Kafka
- **Resources**: 
  - CPU: 100m-500m
  - Memory: 256Mi-512Mi

### 2. Kafka Broker
- **Deployment**: kafka-deployment.yaml
- **Service**: kafka-service.yaml
- **Purpose**: Broker principal para publicação/consumo de eventos
- **Resources**:
  - CPU: 500m-2000m
  - Memory: 1Gi-2Gi
- **Configuration**:
  - Retenção: 30 dias (720 horas)
  - Partições padrão: 6
  - Replicação: 1 (single broker)

### 3. Topics Initialization Job
- **Job**: kafka-topics-job.yaml
- **Purpose**: Criação automática dos tópicos Kafka
- **Topics Criados**:

#### Main Topics (30 dias retenção):
- `os-events` (6 partições) - Eventos da Ordem de Serviço
- `billing-events` (3 partições) - Eventos de Cobrança
- `execution-events` (3 partições) - Eventos de Execução

#### Dead Letter Topics (7 dias retenção):
- `dlt-os-events` (3 partições)
- `dlt-billing-events` (3 partições)
- `dlt-execution-events` (3 partições)

## 🚀 Deploy

### Método 1: Kustomize (Recomendado)
```bash
kubectl apply -k shared-resources/kafka/
```

### Método 2: kubectl direto
```bash
kubectl apply -f shared-resources/kafka/namespace.yaml
kubectl apply -f shared-resources/kafka/zookeeper-service.yaml
kubectl apply -f shared-resources/kafka/zookeeper-deployment.yaml
kubectl apply -f shared-resources/kafka/kafka-service.yaml
kubectl apply -f shared-resources/kafka/kafka-deployment.yaml
kubectl apply -f shared-resources/kafka/kafka-topics-job.yaml
```

## 🔍 Verificação

### Verificar pods
```bash
kubectl get pods -n kafka
```

### Verificar services
```bash
kubectl get svc -n kafka
```

### Verificar Job de criação de tópicos
```bash
kubectl get jobs -n kafka
kubectl logs -n kafka job/kafka-topics-init
```

### Listar tópicos (via pod exec)
```bash
kubectl exec -it -n kafka deployment/kafka -- kafka-topics --list --bootstrap-server localhost:9092
```

### Descrever tópico específico
```bash
kubectl exec -it -n kafka deployment/kafka -- kafka-topics --describe --bootstrap-server localhost:9092 --topic os-events
```

## 🔗 Conexão dos Microserviços

Os microserviços devem usar o seguinte endereço:

```yaml
KAFKA_BOOTSTRAP_SERVERS: kafka.kafka.svc.cluster.local:9092
```

### Exemplo de ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: os-service-config
data:
  KAFKA_BOOTSTRAP_SERVERS: "kafka.kafka.svc.cluster.local:9092"
  KAFKA_CONSUMER_GROUP: "os-service-group"
```

## 📊 Monitoramento

### Kafka Broker Logs
```bash
kubectl logs -n kafka deployment/kafka -f
```

### Zookeeper Logs
```bash
kubectl logs -n kafka deployment/zookeeper -f
```

### Métricas (via Actuator dos serviços)
- `kafka.publisher.events.total`
- `kafka.publisher.events.failed`
- `kafka.consumer.events.total`
- `kafka.circuitbreaker.opened`

## 🔧 Troubleshooting

### Kafka não está pronto
```bash
kubectl describe pod -n kafka -l app=kafka
kubectl logs -n kafka deployment/kafka --tail=100
```

### Job de topics falhou
```bash
kubectl describe job -n kafka kafka-topics-init
kubectl logs -n kafka job/kafka-topics-init
```

### Recriar topics
```bash
kubectl delete job -n kafka kafka-topics-init
kubectl apply -f shared-resources/kafka/kafka-topics-job.yaml
```

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────┐
│          Kafka Namespace (kafka)                │
│                                                 │
│  ┌──────────────┐       ┌──────────────┐      │
│  │  Zookeeper   │◄─────►│    Kafka     │      │
│  │  (Port 2181) │       │  (Port 9092) │      │
│  └──────────────┘       └──────────────┘      │
│         ▲                       ▲              │
│         │                       │              │
│         └───────────────────────┘              │
│              Coordenação                       │
└─────────────────────────────────────────────────┘
                    ▲
                    │
        ┌───────────┼───────────┐
        │           │           │
    os-service  billing   execution
                service    service

Topics: os-events, billing-events, execution-events
DLTs: dlt-os-events, dlt-billing-events, dlt-execution-events
```

## ⚙️ Configurações Importantes

### Retenção de Mensagens
- **Main Topics**: 30 dias (2592000000 ms)
- **DLT Topics**: 7 dias (604800000 ms)

### Partições
- **os-events**: 6 partições (maior throughput)
- **billing-events**: 3 partições
- **execution-events**: 3 partições

### Compressão
- Tipo: `producer` (delegado ao produtor)

## 📝 Notas

- Esta é uma configuração de **single broker** adequada para desenvolvimento/staging
- Para produção, considere usar **Amazon MSK** (Managed Streaming for Kafka)
- O auto-create de tópicos está **desabilitado** para controle explícito
- Dead Letter Topics configurados para retry/análise de falhas
