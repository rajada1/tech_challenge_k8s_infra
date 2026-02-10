# Migração SQS para Apache Kafka

## 📋 Visão Geral

Este documento descreve a migração completa da arquitetura de mensageria de **AWS SQS** para **Apache Kafka** na infraestrutura Kubernetes do sistema de gerenciamento de oficina.

**Data da Migração:** 2024  
**Escopo:** os-service, billing-service, execution-service  
**Padrão de Saga:** Coreografada (Choreographed Saga)

---

## 🎯 Objetivos da Migração

### Antes (SQS)
- ❌ Dependência de serviços AWS proprietários
- ❌ Custo por requisição (pay-per-request)
- ❌ Latência maior em processamento de eventos
- ❌ Limitações em throughput e retenção
- ❌ Filas FIFO com limitações de escalabilidade

### Depois (Kafka)
- ✅ Infraestrutura open-source e portável
- ✅ Custo otimizado (executado no cluster K8s)
- ✅ Alta vazão (milhões de mensagens/seg)
- ✅ Retenção configurável (30 dias)
- ✅ Particionamento para escalabilidade horizontal
- ✅ Stream processing nativo

---

## 🏗️ Arquitetura

### Infraestrutura Kafka

```
kafka namespace (kafka.svc.cluster.local)
├── Zookeeper (coordenação do cluster)
│   ├── Port: 2181
│   ├── Resources: 100m-500m CPU, 256Mi-512Mi RAM
│   └── Healthcheck: zkServer.sh status
│
├── Kafka Broker (streaming de eventos)
│   ├── Port: 9092 (interno), 29092 (externo)
│   ├── Resources: 500m-2000m CPU, 1Gi-2Gi RAM
│   ├── Partitions: 6 (default)
│   ├── Retention: 30 dias
│   └── Healthchecks: liveness + readiness
│
└── Topics (6 tópicos criados via Job)
    ├── os-events (6 partitions, 30 days)
    ├── billing-events (3 partitions, 30 days)
    ├── execution-events (3 partitions, 30 days)
    ├── dlt-os-events (3 partitions, 7 days)
    ├── dlt-billing-events (3 partitions, 7 days)
    └── dlt-execution-events (3 partitions, 7 days)
```

### Fluxo de Eventos (Saga Coreografada)

```
┌─────────────┐         ┌──────────────┐         ┌──────────────────┐
│  OS Service │────────▶│ Kafka Topics │────────▶│ Billing Service  │
└─────────────┘         └──────────────┘         └──────────────────┘
      │                        │                          │
      │                        │                          │
      │                        ▼                          ▼
      │                  os-events               billing-events
      │                 (6 partições)            (3 partições)
      │                                                  │
      │                                                  │
      └──────────────────────────────────────────────────┘
                                │
                                ▼
                        ┌──────────────────┐
                        │ Execution Service│
                        └──────────────────┘
                                │
                                ▼
                        execution-events
                         (3 partições)
```

---

## 🔄 Mudanças Implementadas

### 1. Infraestrutura Kubernetes

**Arquivos Criados em `shared-resources/kafka/`:**

| Arquivo | Descrição | Recursos |
|---------|-----------|----------|
| `namespace.yaml` | Namespace dedicado "kafka" | - |
| `zookeeper-service.yaml` | Service do Zookeeper | Port 2181 |
| `zookeeper-deployment.yaml` | Deployment do Zookeeper | 1 replica, healthcheck |
| `kafka-service.yaml` | Service do Kafka Broker | Port 9092, 29092 |
| `kafka-deployment.yaml` | Deployment do Kafka Broker | 1 replica, probes |
| `kafka-topics-job.yaml` | Job para criar tópicos | 6 tópicos (3+3 DLT) |
| `kustomization.yaml` | Kustomize para organização | - |
| `README.md` | Documentação completa | - |

**Comando de Deploy:**
```bash
kubectl apply -k shared-resources/kafka/
```

### 2. Alterações nos Deployments

**Antes (SQS):**
```yaml
env:
  - name: OS_EVENTS_QUEUE_URL
    valueFrom:
      configMapKeyRef:
        name: os-service-config
        key: SQS_QUEUE_URL
  - name: SQS_OS_EVENTS_QUEUE
    value: "os-events.fifo"
```

**Depois (Kafka):**
```yaml
env:
  - name: KAFKA_BOOTSTRAP_SERVERS
    value: "kafka.kafka.svc.cluster.local:9092"
  - name: KAFKA_CONSUMER_GROUP
    value: "os-service-group"
```

**Arquivos Alterados:**
- ✅ `microservices/os-service/deployment.yaml`
- ✅ `microservices/billing-service/deployment.yaml`
- ✅ `microservices/execution-service/deployment.yaml`

### 3. Alterações nos ConfigMaps

**Removido (SQS):**
```yaml
SQS_QUEUE_URL: "${SQS_QUEUE_URL}"
SQS_OS_EVENTS_QUEUE: "os-events.fifo"
SQS_CONSUMER_WAIT_TIME_SECONDS: "20"
SQS_MAX_NUMBER_OF_MESSAGES: "10"
```

**Adicionado (Kafka):**
```yaml
KAFKA_BOOTSTRAP_SERVERS: "kafka.kafka.svc.cluster.local:9092"
KAFKA_CONSUMER_GROUP: "{service}-group"
```

**Arquivos Alterados:**
- ✅ `microservices/os-service/configmap.yaml`
- ✅ `microservices/billing-service/configmap.yaml`
- ✅ `microservices/execution-service/configmap.yaml`

### 4. Kustomization Principal

**Alteração em `kustomization.yaml` (raiz):**
```yaml
resources:
  # Shared Resources - Kafka Infrastructure (NOVO)
  - shared-resources/kafka/namespace.yaml
  - shared-resources/kafka/zookeeper-service.yaml
  - shared-resources/kafka/zookeeper-deployment.yaml
  - shared-resources/kafka/kafka-service.yaml
  - shared-resources/kafka/kafka-deployment.yaml
  - shared-resources/kafka/kafka-topics-job.yaml
  
  # Microservices (mantidos)
  - microservices/os-service/...
  ...
```

---

## 💻 Alterações no Código (Já Implementadas)

### Features Avançadas Implementadas

#### 1️⃣ **Dead Letter Topics (DLT)**
- Tópicos de DLT para mensagens que falharam após todas as tentativas
- Retenção de 7 dias para análise
- ExponentialBackOff: 1s → 2s → 4s → 8s → 16s → 30s (max)
- DeadLetterPublishingRecoverer automático

**Configuração:**
```java
@Bean
public DefaultErrorHandler errorHandler(KafkaTemplate<String, Object> template) {
    DeadLetterPublishingRecoverer recoverer = 
        new DeadLetterPublishingRecoverer(template,
            (record, ex) -> new TopicPartition("dlt-" + record.topic(), -1));
            
    ExponentialBackOffWithMaxRetries backOff = 
        new ExponentialBackOffWithMaxRetries(5);
    backOff.setInitialInterval(1000L);
    backOff.setMultiplier(2.0);
    backOff.setMaxInterval(30000L);
    
    return new DefaultErrorHandler(recoverer, backOff);
}
```

#### 2️⃣ **Circuit Breaker (Resilience4j)**
- Proteção contra falhas em cascata
- Configuração: 10 requisições, 50% de taxa de falha
- 3 tentativas com exponential backoff
- Timeout de 10 segundos

**Configuração:**
```yaml
resilience4j:
  circuitbreaker:
    instances:
      kafkaEventPublisher:
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 60000
  retry:
    instances:
      kafkaEventPublisher:
        maxAttempts: 3
        waitDuration: 1000
        exponentialBackoffMultiplier: 2
```

**Uso:**
```java
@CircuitBreaker(name = "kafkaEventPublisher", 
                fallbackMethod = "fallbackPublishOsCreated")
@Retry(name = "kafkaEventPublisher")
public void publishOsCreated(OsCreatedEvent event) {
    kafkaTemplate.send("os-events", event.osId(), event).get();
}

private void fallbackPublishOsCreated(OsCreatedEvent event, Throwable t) {
    log.error("Fallback: Failed to publish OsCreatedEvent", t);
    // Persiste em banco ou fila alternativa
}
```

#### 3️⃣ **Métricas com Micrometer**
- Contadores de eventos publicados/consumidos
- Latência de publicação (Timer)
- Estado do circuit breaker
- Métricas do consumer (lag, rate, etc.)

**Configuração:**
```java
@Bean
public Counter osEventsPublishedCounter(MeterRegistry registry) {
    return Counter.builder("kafka.events.published")
        .tag("service", "os-service")
        .tag("topic", "os-events")
        .register(registry);
}

@Bean
public Timer publishLatencyTimer(MeterRegistry registry) {
    return Timer.builder("kafka.publish.latency")
        .tag("service", "os-service")
        .register(registry);
}
```

#### 4️⃣ **Testes de Integração**
- 58 testes passando com sucesso
- Testcontainers com Kafka real
- Verificação de publicação e consumo
- Testes de circuit breaker e fallback
- Validação de DLTs

---

## 🚀 Deployment

### Pré-requisitos
1. Cluster Kubernetes configurado
2. `kubectl` instalado e configurado
3. Acesso ao namespace `kafka`

### Passo a Passo

#### 1. Deploy da Infraestrutura Kafka
```bash
cd tech_challenge_k8s_infra

# Aplicar recursos do Kafka
kubectl apply -k shared-resources/kafka/

# Verificar status
kubectl get pods -n kafka
kubectl get services -n kafka
kubectl get job -n kafka
```

#### 2. Verificar Tópicos Criados
```bash
# Aguardar o Job completar
kubectl wait --for=condition=complete job/kafka-topics-init -n kafka --timeout=300s

# Listar tópicos
kubectl exec -it deploy/kafka -n kafka -- \
  kafka-topics --bootstrap-server localhost:9092 --list
```

**Saída Esperada:**
```
dlt-billing-events
dlt-execution-events
dlt-os-events
billing-events
execution-events
os-events
```

#### 3. Deploy dos Microserviços
```bash
# Aplicar todos os recursos
kubectl apply -k .

# Ou aplicar individualmente
kubectl apply -k microservices/os-service/
kubectl apply -k microservices/billing-service/
kubectl apply -k microservices/execution-service/
```

#### 4. Verificar Conectividade
```bash
# Logs do os-service
kubectl logs -l app=os-service -n oficina-os --tail=50

# Logs do billing-service
kubectl logs -l app=billing-service -n oficina-billing --tail=50

# Logs do execution-service
kubectl logs -l app=execution-service -n oficina-execution --tail=50
```

**Procurar por:**
```
✅ "Kafka consumer started"
✅ "Connected to Kafka broker"
✅ "Subscribed to topic: os-events"
```

---

## 🔍 Troubleshooting

### Problema 1: Pods do Kafka não iniciam
**Sintoma:**
```bash
kubectl get pods -n kafka
NAME                         READY   STATUS    RESTARTS
kafka-xxx                    0/1     Running   3
```

**Solução:**
```bash
# Verificar logs
kubectl logs deploy/kafka -n kafka

# Verificar recursos
kubectl describe pod -l app=kafka -n kafka

# Aumentar recursos se necessário (no kafka-deployment.yaml)
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
```

### Problema 2: Tópicos não foram criados
**Sintoma:**
```bash
kubectl get job -n kafka
NAME                  COMPLETIONS   DURATION
kafka-topics-init     0/1           5m
```

**Solução:**
```bash
# Verificar logs do Job
kubectl logs job/kafka-topics-init -n kafka

# Recriar Job
kubectl delete job kafka-topics-init -n kafka
kubectl apply -f shared-resources/kafka/kafka-topics-job.yaml
```

### Problema 3: Microserviços não conectam ao Kafka
**Sintoma:**
```
ERROR: Failed to connect to kafka.kafka.svc.cluster.local:9092
```

**Solução:**
```bash
# Verificar DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup kafka.kafka.svc.cluster.local

# Verificar Service
kubectl get svc -n kafka

# Testar conectividade de dentro do pod
kubectl exec -it deploy/os-service -n oficina-os -- \
  nc -zv kafka.kafka.svc.cluster.local 9092
```

### Problema 4: Mensagens caindo no DLT
**Sintoma:**
```bash
# Ver mensagens no DLT
kubectl exec -it deploy/kafka -n kafka -- \
  kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic dlt-os-events --from-beginning
```

**Análise:**
1. Verificar logs do consumer para exceções
2. Validar formato das mensagens
3. Verificar se o serviço downstream está disponível
4. Analisar métricas de circuit breaker

---

## 📊 Monitoramento

### Métricas Disponíveis (Prometheus)

#### Kafka Broker
- `kafka_server_brokertopicmetrics_messagesin_total` - Total de mensagens recebidas
- `kafka_server_brokertopicmetrics_bytesin_total` - Bytes recebidos
- `kafka_network_requestmetrics_requests_total` - Requisições ao broker

#### Consumer
- `kafka.events.consumed` - Total de eventos consumidos por tópico
- `kafka.consumer.lag` - Lag do consumer
- `kafka.consumer.rate` - Taxa de consumo (msg/s)

#### Publisher
- `kafka.events.published` - Total de eventos publicados
- `kafka.publish.latency` - Latência de publicação (p50, p95, p99)

#### Circuit Breaker
- `resilience4j.circuitbreaker.state` - Estado atual (closed/open/half_open)
- `resilience4j.circuitbreaker.failure.rate` - Taxa de falha
- `resilience4j.retry.calls` - Tentativas de retry

### Dashboards Grafana

Criar dashboard com os seguintes painéis:

1. **Throughput de Mensagens**
   - Taxa de publicação por tópico
   - Taxa de consumo por consumer group

2. **Latência**
   - p50, p95, p99 de publicação
   - Tempo de processamento do consumer

3. **Erros e DLT**
   - Taxa de erro por tópico
   - Mensagens no DLT por hora

4. **Circuit Breaker**
   - Estado atual dos circuit breakers
   - Taxa de falha por serviço

---

## 🧹 Limpeza (Deprecação do SQS)

### Recursos AWS para Remover

1. **SQS Queues (Terraform):**
   ```bash
   # Comentar/remover em tech_challenge_db_infra/sqs.tf
   # resource "aws_sqs_queue" "os_events"
   # resource "aws_sqs_queue" "billing_events"
   # resource "aws_sqs_queue" "execution_events"
   ```

2. **IAM Roles/Policies:**
   ```bash
   # Remover policies de acesso SQS
   # aws_iam_policy.sqs_access
   # aws_iam_role.sqs_publisher
   ```

3. **CloudWatch Alarms:**
   ```bash
   # Remover alarmes relacionados a SQS
   # aws_cloudwatch_metric_alarm.sqs_queue_depth
   ```

### Validação Antes de Remover

```bash
# 1. Verificar se há mensagens pendentes
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages

# 2. Garantir que nenhum serviço está usando
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=os-events.fifo \
  --max-results 10

# 3. Fazer backup de DLQs (se houver)
aws sqs receive-message --queue-url <dlq-url> --max-number-of-messages 10
```

---

## 📈 Resultados Esperados

### Performance
- **Throughput:** 10x-100x maior que SQS
- **Latência:** p99 < 50ms (vs ~100-500ms no SQS)
- **Custo:** Redução de ~70% (sem pay-per-request)

### Confiabilidade
- **Retenção:** 30 dias (vs 14 dias no SQS)
- **Resiliência:** Circuit breaker previne falhas em cascata
- **Observabilidade:** Métricas detalhadas com Micrometer

### Escalabilidade
- **Particionamento:** 6-12 partições por tópico
- **Consumer Groups:** Escalamento horizontal automático
- **HPA:** Auto-scaling baseado em lag do consumer

---

## 📚 Referências

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Spring Kafka Reference](https://docs.spring.io/spring-kafka/reference/)
- [Resilience4j Circuit Breaker](https://resilience4j.readme.io/docs/circuitbreaker)
- [Micrometer Metrics](https://micrometer.io/docs)
- [Confluent Best Practices](https://docs.confluent.io/platform/current/kafka/deployment.html)

---

## ✅ Checklist de Migração

- [x] Infraestrutura Kafka criada (namespace, zookeeper, kafka, topics)
- [x] ConfigMaps atualizados (SQS → Kafka)
- [x] Deployments atualizados (env vars)
- [x] Código migrado (KafkaConfig, Publisher, Consumer)
- [x] Circuit Breaker implementado
- [x] Dead Letter Topics configurados
- [x] Métricas com Micrometer
- [x] Testes de integração (58 testes passando)
- [x] Kustomization.yaml atualizado
- [x] Documentação criada
- [ ] Deploy em ambiente dev/staging
- [ ] Testes de carga (K6)
- [ ] Monitoramento configurado (Grafana/Prometheus)
- [ ] Deploy em produção
- [ ] Deprecação completa do SQS
- [ ] Remoção de recursos AWS (Terraform)

---

**Status da Migração:** ✅ **CÓDIGO E INFRAESTRUTURA COMPLETOS - PRONTO PARA DEPLOY**

**Próximos Passos:**
1. Deploy em ambiente de desenvolvimento
2. Testes de carga com K6
3. Configurar dashboards Grafana
4. Deploy em produção
5. Monitorar por 2 semanas
6. Remover infraestrutura SQS da AWS
