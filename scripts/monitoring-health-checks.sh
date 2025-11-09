#!/bin/bash

################################################################################
# Pivori Studio - Monitoring & Health Checks Script
# Description: Comprehensive monitoring and health check suite for production
# Author: Manus AI
# Version: 1.0.0
################################################################################

set -euo pipefail

# Configuration
NAMESPACE="production"
MONITORING_NAMESPACE="monitoring"
PROMETHEUS_URL="http://prometheus:9090"
GRAFANA_URL="http://grafana:3000"
ALERTMANAGER_URL="http://alertmanager:9093"
LOG_DIR="/var/log/pivori-monitoring"
METRICS_FILE="${LOG_DIR}/metrics-$(date +%Y%m%d-%H%M%S).json"

# Couleurs pour l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Fonctions utilitaires
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

################################################################################
# Vérifications de santé des services
################################################################################

check_kubernetes_health() {
    log_info "Vérification de la santé du cluster Kubernetes..."
    
    # Vérifier les nodes
    local not_ready_nodes=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
    if [ "$not_ready_nodes" -eq 0 ]; then
        log_success "Tous les nodes Kubernetes sont ready"
    else
        log_error "$not_ready_nodes nodes ne sont pas ready"
        return 1
    fi
    
    # Vérifier les pods
    local not_running_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep -v "Running\|Succeeded" | wc -l)
    if [ "$not_running_pods" -eq 0 ]; then
        log_success "Tous les pods sont running"
    else
        log_warning "$not_running_pods pods ne sont pas running"
        kubectl get pods -n "$NAMESPACE" --no-headers | grep -v "Running\|Succeeded"
    fi
}

check_prometheus_health() {
    log_info "Vérification de la santé de Prometheus..."
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "${PROMETHEUS_URL}/-/healthy")
    if [ "$response" = "200" ]; then
        log_success "Prometheus est healthy"
    else
        log_error "Prometheus health check failed (HTTP $response)"
        return 1
    fi
    
    # Vérifier le nombre de targets
    local targets=$(curl -s "${PROMETHEUS_URL}/api/v1/targets" | grep -o '"health":"up"' | wc -l)
    log_info "Prometheus targets up: $targets"
}

check_grafana_health() {
    log_info "Vérification de la santé de Grafana..."
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "${GRAFANA_URL}/api/health")
    if [ "$response" = "200" ]; then
        log_success "Grafana est healthy"
    else
        log_error "Grafana health check failed (HTTP $response)"
        return 1
    fi
}

check_alertmanager_health() {
    log_info "Vérification de la santé d'Alertmanager..."
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "${ALERTMANAGER_URL}/-/healthy")
    if [ "$response" = "200" ]; then
        log_success "Alertmanager est healthy"
    else
        log_error "Alertmanager health check failed (HTTP $response)"
        return 1
    fi
}

################################################################################
# Vérifications de performance
################################################################################

check_latency_metrics() {
    log_info "Vérification des métriques de latency..."
    
    # P95 Latency
    local p95=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=histogram_quantile(0.95,sum(rate(http_request_duration_seconds_bucket%5B5m%5D))by(le))" | grep -o '"value":\[[^]]*\]' | head -1 | grep -o '[0-9.]*' | tail -1)
    
    if (( $(echo "$p95 < 0.5" | bc -l) )); then
        log_success "P95 Latency: ${p95}s (OK)"
    elif (( $(echo "$p95 < 1.0" | bc -l) )); then
        log_warning "P95 Latency: ${p95}s (WARNING)"
    else
        log_error "P95 Latency: ${p95}s (CRITICAL)"
        return 1
    fi
    
    # P99 Latency
    local p99=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=histogram_quantile(0.99,sum(rate(http_request_duration_seconds_bucket%5B5m%5D))by(le))" | grep -o '"value":\[[^]]*\]' | head -1 | grep -o '[0-9.]*' | tail -1)
    
    if (( $(echo "$p99 < 1.0" | bc -l) )); then
        log_success "P99 Latency: ${p99}s (OK)"
    elif (( $(echo "$p99 < 2.0" | bc -l) )); then
        log_warning "P99 Latency: ${p99}s (WARNING)"
    else
        log_error "P99 Latency: ${p99}s (CRITICAL)"
        return 1
    fi
}

check_error_rate() {
    log_info "Vérification du taux d'erreur..."
    
    local error_rate=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=(sum(rate(http_requests_total%7Bstatus=%7E%225..%22%7D%5B5m%5D))%2Fsum(rate(http_requests_total%5B5m%5D)))*100" | grep -o '"value":\[[^]]*\]' | head -1 | grep -o '[0-9.]*' | tail -1)
    
    if (( $(echo "$error_rate < 0.1" | bc -l) )); then
        log_success "Error Rate: ${error_rate}% (OK)"
    elif (( $(echo "$error_rate < 1.0" | bc -l) )); then
        log_warning "Error Rate: ${error_rate}% (WARNING)"
    else
        log_error "Error Rate: ${error_rate}% (CRITICAL)"
        return 1
    fi
}

check_uptime() {
    log_info "Vérification de l'uptime..."
    
    local uptime=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=100-(avg(rate(http_requests_total%7Bstatus=%7E%225..%22%7D%5B5m%5D))*100)" | grep -o '"value":\[[^]]*\]' | head -1 | grep -o '[0-9.]*' | tail -1)
    
    if (( $(echo "$uptime > 99.9" | bc -l) )); then
        log_success "Uptime: ${uptime}% (OK)"
    elif (( $(echo "$uptime > 99.0" | bc -l) )); then
        log_warning "Uptime: ${uptime}% (WARNING)"
    else
        log_error "Uptime: ${uptime}% (CRITICAL)"
        return 1
    fi
}

################################################################################
# Vérifications de ressources
################################################################################

check_memory_usage() {
    log_info "Vérification de l'utilisation mémoire..."
    
    local memory_usage=$(kubectl top pods -n "$NAMESPACE" --no-headers | awk '{sum+=$2} END {print sum}')
    local memory_limit=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.memory}' | tr ' ' '\n' | awk '{gsub(/Ki/,""); sum+=$1} END {print int(sum/1024/1024)}')
    
    local percentage=$((memory_usage * 100 / memory_limit))
    
    if [ "$percentage" -lt 70 ]; then
        log_success "Memory Usage: ${percentage}% (OK)"
    elif [ "$percentage" -lt 85 ]; then
        log_warning "Memory Usage: ${percentage}% (WARNING)"
    else
        log_error "Memory Usage: ${percentage}% (CRITICAL)"
        return 1
    fi
}

check_cpu_usage() {
    log_info "Vérification de l'utilisation CPU..."
    
    local cpu_usage=$(kubectl top pods -n "$NAMESPACE" --no-headers | awk '{sum+=$1} END {print sum}')
    local cpu_limit=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.cpu}' | tr ' ' '\n' | awk '{gsub(/m/,""); sum+=$1} END {print int(sum/1000)}')
    
    local percentage=$((cpu_usage * 100 / cpu_limit))
    
    if [ "$percentage" -lt 60 ]; then
        log_success "CPU Usage: ${percentage}% (OK)"
    elif [ "$percentage" -lt 80 ]; then
        log_warning "CPU Usage: ${percentage}% (WARNING)"
    else
        log_error "CPU Usage: ${percentage}% (CRITICAL)"
        return 1
    fi
}

check_disk_usage() {
    log_info "Vérification de l'utilisation disque..."
    
    kubectl exec -n "$MONITORING_NAMESPACE" -it prometheus-0 -- df -h | tail -n +2 | while read line; do
        local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        local mount=$(echo "$line" | awk '{print $6}')
        
        if [ "$usage" -lt 70 ]; then
            log_success "Disk $mount: ${usage}% (OK)"
        elif [ "$usage" -lt 85 ]; then
            log_warning "Disk $mount: ${usage}% (WARNING)"
        else
            log_error "Disk $mount: ${usage}% (CRITICAL)"
            return 1
        fi
    done
}

################################################################################
# Vérifications de connectivité
################################################################################

check_database_connectivity() {
    log_info "Vérification de la connectivité base de données..."
    
    # PostgreSQL
    local pg_pod=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -n "$NAMESPACE" "$pg_pod" -- pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
        log_success "PostgreSQL est accessible"
    else
        log_error "PostgreSQL n'est pas accessible"
        return 1
    fi
    
    # Redis
    local redis_pod=$(kubectl get pods -n "$NAMESPACE" -l app=redis -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -n "$NAMESPACE" "$redis_pod" -- redis-cli ping > /dev/null 2>&1; then
        log_success "Redis est accessible"
    else
        log_error "Redis n'est pas accessible"
        return 1
    fi
}

check_service_connectivity() {
    log_info "Vérification de la connectivité des services..."
    
    local services=(
        "geolocation:8010"
        "routing:8020"
        "trading:8040"
        "market-data:8050"
        "iptv:8070"
        "game:8100"
    )
    
    for service in "${services[@]}"; do
        local name="${service%:*}"
        local port="${service#*:}"
        
        if curl -s "http://${name}:${port}/health" > /dev/null 2>&1; then
            log_success "Service $name est accessible"
        else
            log_warning "Service $name n'est pas accessible"
        fi
    done
}

################################################################################
# Vérifications de sécurité
################################################################################

check_certificate_expiry() {
    log_info "Vérification de l'expiration des certificats..."
    
    local certs=$(kubectl get certificate -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    for cert in $certs; do
        local expiry=$(kubectl get certificate "$cert" -n "$NAMESPACE" -o jsonpath='{.status.renewalTime}')
        local days_left=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))
        
        if [ "$days_left" -gt 30 ]; then
            log_success "Certificate $cert: $days_left days left (OK)"
        elif [ "$days_left" -gt 7 ]; then
            log_warning "Certificate $cert: $days_left days left (WARNING)"
        else
            log_error "Certificate $cert: $days_left days left (CRITICAL)"
            return 1
        fi
    done
}

check_rbac_policies() {
    log_info "Vérification des politiques RBAC..."
    
    local roles=$(kubectl get roles -n "$NAMESPACE" --no-headers | wc -l)
    local rolebindings=$(kubectl get rolebindings -n "$NAMESPACE" --no-headers | wc -l)
    
    if [ "$roles" -gt 0 ] && [ "$rolebindings" -gt 0 ]; then
        log_success "RBAC policies configurées (Roles: $roles, RoleBindings: $rolebindings)"
    else
        log_warning "RBAC policies incomplètes"
    fi
}

################################################################################
# Vérifications de backup
################################################################################

check_backup_status() {
    log_info "Vérification du statut des backups..."
    
    local backups=$(kubectl get backups -n "$MONITORING_NAMESPACE" -o jsonpath='{.items[*].status.phase}')
    
    if echo "$backups" | grep -q "Failed"; then
        log_error "Certains backups ont échoué"
        return 1
    else
        log_success "Tous les backups sont en bon état"
    fi
}

check_backup_age() {
    log_info "Vérification de l'âge des backups..."
    
    local latest_backup=$(kubectl get backups -n "$MONITORING_NAMESPACE" -o jsonpath='{.items[-1].metadata.creationTimestamp}')
    local backup_age=$(( ($(date +%s) - $(date -d "$latest_backup" +%s)) / 3600 ))
    
    if [ "$backup_age" -lt 24 ]; then
        log_success "Dernier backup: $backup_age heures (OK)"
    elif [ "$backup_age" -lt 48 ]; then
        log_warning "Dernier backup: $backup_age heures (WARNING)"
    else
        log_error "Dernier backup: $backup_age heures (CRITICAL)"
        return 1
    fi
}

################################################################################
# Génération de rapports
################################################################################

generate_health_report() {
    log_info "Génération du rapport de santé..."
    
    mkdir -p "$LOG_DIR"
    
    local report_file="${LOG_DIR}/health-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "======================================"
        echo "Pivori Studio - Health Report"
        echo "======================================"
        echo "Generated: $(date)"
        echo ""
        
        echo "Kubernetes Status:"
        kubectl get nodes --no-headers
        echo ""
        
        echo "Pod Status:"
        kubectl get pods -n "$NAMESPACE" --no-headers | head -20
        echo ""
        
        echo "Resource Usage:"
        kubectl top nodes
        echo ""
        
        echo "Active Alerts:"
        curl -s "${ALERTMANAGER_URL}/api/v1/alerts" | grep -o '"status":"firing"' | wc -l
        echo ""
        
    } > "$report_file"
    
    log_success "Rapport généré: $report_file"
}

generate_metrics_snapshot() {
    log_info "Génération d'un snapshot des métriques..."
    
    mkdir -p "$LOG_DIR"
    
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"metrics\": {"
        
        # P95 Latency
        local p95=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=histogram_quantile(0.95,sum(rate(http_request_duration_seconds_bucket%5B5m%5D))by(le))" | grep -o '"value":\[[^]]*\]' | head -1)
        echo "    \"p95_latency\": $p95,"
        
        # P99 Latency
        local p99=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=histogram_quantile(0.99,sum(rate(http_request_duration_seconds_bucket%5B5m%5D))by(le))" | grep -o '"value":\[[^]]*\]' | head -1)
        echo "    \"p99_latency\": $p99,"
        
        # Error Rate
        local error_rate=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=(sum(rate(http_requests_total%7Bstatus=%7E%225..%22%7D%5B5m%5D))%2Fsum(rate(http_requests_total%5B5m%5D)))*100" | grep -o '"value":\[[^]]*\]' | head -1)
        echo "    \"error_rate\": $error_rate"
        
        echo "  }"
        echo "}"
    } > "$METRICS_FILE"
    
    log_success "Snapshot généré: $METRICS_FILE"
}

################################################################################
# Main execution
################################################################################

main() {
    log_info "Démarrage des health checks..."
    
    local failed=0
    
    # Kubernetes checks
    check_kubernetes_health || ((failed++))
    
    # Monitoring stack checks
    check_prometheus_health || ((failed++))
    check_grafana_health || ((failed++))
    check_alertmanager_health || ((failed++))
    
    # Performance checks
    check_latency_metrics || ((failed++))
    check_error_rate || ((failed++))
    check_uptime || ((failed++))
    
    # Resource checks
    check_memory_usage || ((failed++))
    check_cpu_usage || ((failed++))
    check_disk_usage || ((failed++))
    
    # Connectivity checks
    check_database_connectivity || ((failed++))
    check_service_connectivity || ((failed++))
    
    # Security checks
    check_certificate_expiry || ((failed++))
    check_rbac_policies || ((failed++))
    
    # Backup checks
    check_backup_status || ((failed++))
    check_backup_age || ((failed++))
    
    # Generate reports
    generate_health_report
    generate_metrics_snapshot
    
    echo ""
    if [ "$failed" -eq 0 ]; then
        log_success "Tous les health checks sont passés!"
        exit 0
    else
        log_error "$failed health checks ont échoué"
        exit 1
    fi
}

# Run main function
main "$@"

