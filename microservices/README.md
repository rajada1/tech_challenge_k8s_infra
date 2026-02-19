# Oficina Management System - Microservices Kustomization

This directory contains per-service Kustomizations that can be deployed independently or together.

## Structure

```
microservices/
├── os-service/          # Order Service manifests
├── billing-service/     # Billing Service manifests
└── execution-service/   # Execution Service manifests
```

## Deploy Individual Service

```bash
# Deploy only OS Service
kubectl apply -k microservices/os-service/

# Deploy only Billing Service
kubectl apply -k microservices/billing-service/

# Deploy only Execution Service
kubectl apply -k microservices/execution-service/
```

## Deploy All Services

From the root of this repository:

```bash
# Deploy all microservices at once
kubectl apply -k .
```

## Prerequisites

- EKS cluster running (provisioned by terraform in parent directory)
- kubectl configured to access the cluster
- Database endpoints configured in ConfigMaps
- Secrets properly configured

## Customization

Each service has its own kustomization.yaml that can be customized independently.
