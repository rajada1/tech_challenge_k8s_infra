#!/bin/bash

##############################################################################
# New Relic EKS Infrastructure - Validation Script
# 
# This script validates the New Relic integration deployment on EKS cluster
# 
# Usage: ./validate-newrelic.sh [cluster-name] [region]
# Example: ./validate-newrelic.sh tech-challenge-cluster us-east-1
#
# Requirements:
#   - kubectl configured
#   - aws cli configured
#   - terraform state available
#   - jq installed (optional, for better output)
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"
INFO="${BLUE}ℹ${NC}"

# Default values
CLUSTER_NAME="${1:-tech-challenge-cluster}"
AWS_REGION="${2:-us-east-1}"
NAMESPACE="newrelic"

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

##############################################################################
# Helper Functions
##############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}>>> $1${NC}"
    echo ""
}

print_success() {
    echo -e "${CHECK} $1"
    ((TESTS_PASSED++))
}

print_error() {
    echo -e "${CROSS} $1"
    ((TESTS_FAILED++))
}

print_warning() {
    echo -e "${WARN} $1"
    ((TESTS_WARNED++))
}

print_info() {
    echo -e "${INFO} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

##############################################################################
# Validation Functions
##############################################################################

validate_prerequisites() {
    print_header "1. VALIDATING PREREQUISITES"
    
    print_section "Checking required commands"
    check_command "kubectl" || exit 1
    check_command "aws" || exit 1
    check_command "terraform" || exit 1
    check_command "helm"
    
    print_section "Checking AWS credentials"
    if aws sts get-caller-identity &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        print_success "AWS credentials configured (Account: $ACCOUNT_ID)"
    else
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    print_section "Checking Terraform state"
    if terraform output &> /dev/null; then
        print_success "Terraform state available"
    else
        print_warning "Terraform state not available (not in terraform directory?)"
    fi
}

validate_eks_cluster() {
    print_header "2. VALIDATING EKS CLUSTER"
    
    print_section "Checking EKS cluster"
    if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &> /dev/null; then
        CLUSTER_STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.status' --output text)
        if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
            print_success "EKS cluster '$CLUSTER_NAME' is ACTIVE"
        else
            print_error "EKS cluster status: $CLUSTER_STATUS"
        fi
    else
        print_error "EKS cluster '$CLUSTER_NAME' not found"
        exit 1
    fi
    
    print_section "Checking kubectl connectivity"
    if kubectl cluster-info &> /dev/null; then
        print_success "kubectl can connect to cluster"
    else
        print_error "kubectl cannot connect to cluster"
        echo "  Run: aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION"
        exit 1
    fi
    
    print_section "Checking nodes"
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$NODE_COUNT" -gt 0 ]; then
        print_success "Found $NODE_COUNT node(s)"
        
        READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || true)
        if [ "$READY_NODES" -eq "$NODE_COUNT" ]; then
            print_success "All $NODE_COUNT nodes are Ready"
        else
            print_error "Only $READY_NODES/$NODE_COUNT nodes are Ready"
        fi
    else
        print_error "No nodes found"
    fi
}

validate_newrelic_namespace() {
    print_header "3. VALIDATING NEW RELIC NAMESPACE"
    
    print_section "Checking namespace"
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_success "Namespace '$NAMESPACE' exists"
    else
        print_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    print_section "Checking ConfigMaps"
    CM_COUNT=$(kubectl get configmap -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$CM_COUNT" -gt 0 ]; then
        print_success "Found $CM_COUNT ConfigMap(s)"
    else
        print_warning "No ConfigMaps found"
    fi
    
    print_section "Checking Secrets"
    SECRET_COUNT=$(kubectl get secret -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$SECRET_COUNT" -gt 0 ]; then
        print_success "Found $SECRET_COUNT Secret(s)"
    else
        print_warning "No Secrets found"
    fi
    
    print_section "Checking ServiceAccounts"
    SA_COUNT=$(kubectl get serviceaccount -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$SA_COUNT" -gt 0 ]; then
        print_success "Found $SA_COUNT ServiceAccount(s)"
    else
        print_warning "No ServiceAccounts found"
    fi
}

validate_newrelic_pods() {
    print_header "4. VALIDATING NEW RELIC PODS"
    
    print_section "Checking pods"
    POD_COUNT=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$POD_COUNT" -gt 0 ]; then
        print_success "Found $POD_COUNT pod(s)"
    else
        print_error "No pods found in namespace '$NAMESPACE'"
        return
    fi
    
    print_section "Checking pod status"
    RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "Running" || true)
    if [ "$RUNNING_PODS" -eq "$POD_COUNT" ]; then
        print_success "All $POD_COUNT pods are Running"
    else
        print_error "Only $RUNNING_PODS/$POD_COUNT pods are Running"
        
        echo ""
        echo "Non-running pods:"
        kubectl get pods -n "$NAMESPACE" | grep -v "Running" | tail -n +2
    fi
    
    print_section "Checking pod readiness"
    READY_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{if ($2 ~ /^[0-9]+\/[0-9]+$/) {split($2,a,"/"); if (a[1] == a[2]) count++}} END {print count+0}')
    if [ "$READY_PODS" -eq "$POD_COUNT" ]; then
        print_success "All $POD_COUNT pods are Ready"
    else
        print_warning "$READY_PODS/$POD_COUNT pods are Ready"
    fi
    
    print_section "Checking pod restarts"
    MAX_RESTARTS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $4}' | sort -n | tail -1)
    if [ "$MAX_RESTARTS" -le 2 ]; then
        print_success "Pod restarts are low (max: $MAX_RESTARTS)"
    else
        print_warning "Some pods have many restarts (max: $MAX_RESTARTS)"
    fi
    
    print_section "Checking DaemonSets"
    DS_INFRA=$(kubectl get daemonset -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "newrelic-infrastructure" || true)
    if [ "$DS_INFRA" -gt 0 ]; then
        print_success "newrelic-infrastructure DaemonSet found"
    else
        print_warning "newrelic-infrastructure DaemonSet not found"
    fi
    
    DS_FLUENT=$(kubectl get daemonset -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "fluent-bit" || true)
    if [ "$DS_FLUENT" -gt 0 ]; then
        print_success "fluent-bit DaemonSet found"
    else
        print_warning "fluent-bit DaemonSet not found"
    fi
    
    print_section "Checking Deployments"
    DEP_COUNT=$(kubectl get deployment -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$DEP_COUNT" -ge 3 ]; then
        print_success "Found $DEP_COUNT Deployment(s) (expected: ≥3)"
    else
        print_warning "Found only $DEP_COUNT Deployment(s) (expected: ≥3)"
    fi
}

validate_newrelic_logs() {
    print_header "5. VALIDATING NEW RELIC LOGS"
    
    print_section "Checking Infrastructure Agent logs"
    INFRA_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=newrelic-infrastructure --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    
    if [ -n "$INFRA_POD" ]; then
        print_info "Checking logs from pod: $INFRA_POD"
        
        if kubectl logs -n "$NAMESPACE" "$INFRA_POD" --tail=100 2>/dev/null | grep -qi "success"; then
            print_success "Infrastructure agent logs show successful operations"
        else
            print_warning "No success messages found in logs (may take a few minutes)"
        fi
        
        if kubectl logs -n "$NAMESPACE" "$INFRA_POD" --tail=100 2>/dev/null | grep -qi "error"; then
            print_warning "Error messages found in logs"
            echo ""
            echo "Recent errors:"
            kubectl logs -n "$NAMESPACE" "$INFRA_POD" --tail=100 2>/dev/null | grep -i "error" | tail -5
        else
            print_success "No error messages in recent logs"
        fi
    else
        print_warning "Infrastructure agent pod not found"
    fi
}

validate_helm_release() {
    print_header "6. VALIDATING HELM RELEASE"
    
    if ! command -v helm &> /dev/null; then
        print_warning "Helm not installed, skipping Helm validation"
        return
    fi
    
    print_section "Checking Helm releases"
    if helm list -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q "newrelic-bundle"; then
        print_success "Helm release 'newrelic-bundle' found"
        
        RELEASE_STATUS=$(helm list -n "$NAMESPACE" --no-headers 2>/dev/null | grep "newrelic-bundle" | awk '{print $8}')
        if [ "$RELEASE_STATUS" = "deployed" ]; then
            print_success "Helm release status: deployed"
        else
            print_error "Helm release status: $RELEASE_STATUS"
        fi
        
        CHART_VERSION=$(helm list -n "$NAMESPACE" --no-headers 2>/dev/null | grep "newrelic-bundle" | awk '{print $9}')
        print_info "Chart version: $CHART_VERSION"
    else
        print_error "Helm release 'newrelic-bundle' not found"
    fi
}

validate_newrelic_resources() {
    print_header "7. VALIDATING NEW RELIC RESOURCES"
    
    print_section "Checking Terraform outputs"
    
    if terraform output &> /dev/null; then
        if terraform output newrelic_integration_installed 2>/dev/null | grep -q "true"; then
            print_success "New Relic integration marked as installed"
        else
            print_warning "New Relic integration not marked as installed in Terraform state"
        fi
        
        if terraform output newrelic_dashboard_url &> /dev/null; then
            DASHBOARD_URL=$(terraform output -raw newrelic_dashboard_url 2>/dev/null)
            print_success "Dashboard URL available"
            print_info "  URL: $DASHBOARD_URL"
        else
            print_warning "Dashboard URL not found in Terraform outputs"
        fi
        
        if terraform output newrelic_alert_policy_id &> /dev/null; then
            POLICY_ID=$(terraform output -raw newrelic_alert_policy_id 2>/dev/null)
            print_success "Alert policy ID available: $POLICY_ID"
        else
            print_warning "Alert policy ID not found in Terraform outputs"
        fi
    else
        print_warning "Cannot check Terraform outputs (not in terraform directory?)"
    fi
}

validate_resource_usage() {
    print_header "8. VALIDATING RESOURCE USAGE"
    
    print_section "Checking node resources"
    if command -v kubectl &> /dev/null && kubectl top nodes &> /dev/null; then
        echo ""
        kubectl top nodes
        echo ""
        
        MAX_CPU=$(kubectl top nodes --no-headers 2>/dev/null | awk '{print $3}' | sed 's/%//' | sort -n | tail -1)
        if [ "$MAX_CPU" -lt 80 ]; then
            print_success "Node CPU usage is healthy (max: ${MAX_CPU}%)"
        else
            print_warning "Node CPU usage is high (max: ${MAX_CPU}%)"
        fi
        
        MAX_MEM=$(kubectl top nodes --no-headers 2>/dev/null | awk '{print $5}' | sed 's/%//' | sort -n | tail -1)
        if [ "$MAX_MEM" -lt 80 ]; then
            print_success "Node memory usage is healthy (max: ${MAX_MEM}%)"
        else
            print_warning "Node memory usage is high (max: ${MAX_MEM}%)"
        fi
    else
        print_warning "Metrics server not available (cannot check resource usage)"
    fi
    
    print_section "Checking New Relic pod resources"
    if command -v kubectl &> /dev/null && kubectl top pods -n "$NAMESPACE" &> /dev/null; then
        echo ""
        kubectl top pods -n "$NAMESPACE"
        echo ""
        print_success "New Relic pods resource usage displayed above"
    else
        print_warning "Cannot check pod resource usage"
    fi
}

validate_connectivity() {
    print_header "9. VALIDATING NEW RELIC CONNECTIVITY"
    
    print_section "Testing connectivity to New Relic"
    if kubectl run test-connectivity --image=busybox --restart=Never --rm -i --quiet -- wget -O- https://metric-api.newrelic.com/health 2>/dev/null | grep -q "OK"; then
        print_success "Connectivity to New Relic metric API is working"
    else
        print_warning "Could not test connectivity (timeout or network issue)"
    fi
}

print_summary() {
    print_header "VALIDATION SUMMARY"
    
    TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))
    
    echo -e "${GREEN}Passed:  $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:  $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Warnings: $TESTS_WARNED${NC}"
    echo -e "Total:   $TOTAL_TESTS"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        if [ $TESTS_WARNED -eq 0 ]; then
            echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║  ✓ ALL VALIDATIONS PASSED PERFECTLY!  ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${GREEN}New Relic integration is working correctly!${NC}"
            echo ""
            return 0
        else
            echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
            echo -e "${YELLOW}║  ⚠ VALIDATIONS PASSED WITH WARNINGS   ║${NC}"
            echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${YELLOW}New Relic integration is working but has warnings.${NC}"
            echo -e "${YELLOW}Review the warnings above.${NC}"
            echo ""
            return 0
        fi
    else
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ✗ SOME VALIDATIONS FAILED             ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${RED}New Relic integration has issues.${NC}"
        echo -e "${RED}Review the errors above and fix them.${NC}"
        echo ""
        echo "Troubleshooting tips:"
        echo "  1. Check pod logs: kubectl logs -n $NAMESPACE <pod-name>"
        echo "  2. Describe problematic pods: kubectl describe pod -n $NAMESPACE <pod-name>"
        echo "  3. Verify New Relic credentials in terraform.tfvars"
        echo "  4. Check Terraform apply completed successfully"
        echo "  5. Review documentation: README.md, NEW_RELIC_EKS_INFRASTRUCTURE.md"
        echo ""
        return 1
    fi
}

print_next_steps() {
    if [ $TESTS_FAILED -eq 0 ]; then
        print_header "NEXT STEPS"
        
        echo "1. Access New Relic Dashboard:"
        if terraform output newrelic_dashboard_url &> /dev/null; then
            echo -e "   ${BLUE}$(terraform output -raw newrelic_dashboard_url 2>/dev/null)${NC}"
        else
            echo "   Run: terraform output newrelic_dashboard_url"
        fi
        echo ""
        
        echo "2. Access Kubernetes Explorer:"
        echo -e "   ${BLUE}https://one.newrelic.com/kubernetes${NC}"
        echo ""
        
        echo "3. Query your data:"
        echo -e "   ${BLUE}https://one.newrelic.com/data-exploration/query-builder${NC}"
        echo "   Example query:"
        echo "   FROM K8sNodeSample SELECT * WHERE clusterName = '$CLUSTER_NAME'"
        echo ""
        
        echo "4. Check Alerts:"
        echo -e "   ${BLUE}https://one.newrelic.com/alerts-ai/condition-builder${NC}"
        echo ""
        
        echo "5. View Logs:"
        echo -e "   ${BLUE}https://one.newrelic.com/logger${NC}"
        echo ""
        
        echo "For more information, see:"
        echo "  - README.md"
        echo "  - NEW_RELIC_EKS_INFRASTRUCTURE.md"
        echo "  - QUICK_START.md"
        echo ""
    fi
}

##############################################################################
# Main Execution
##############################################################################

main() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║  New Relic EKS Infrastructure - Validation Script        ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    print_info "Cluster: $CLUSTER_NAME"
    print_info "Region:  $AWS_REGION"
    print_info "Namespace: $NAMESPACE"
    echo ""
    
    validate_prerequisites
    validate_eks_cluster
    validate_newrelic_namespace
    validate_newrelic_pods
    validate_newrelic_logs
    validate_helm_release
    validate_newrelic_resources
    validate_resource_usage
    validate_connectivity
    
    print_summary
    SUMMARY_RESULT=$?
    
    print_next_steps
    
    exit $SUMMARY_RESULT
}

# Run main function
main
