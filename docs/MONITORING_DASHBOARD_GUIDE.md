# 📊 Pivori Studio - Production Monitoring Dashboard Guide

**Version**: 1.0.0  
**Date**: 2025-11-09  
**Author**: Manus AI  
**Status**: Production-Ready

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Dashboard Components](#dashboard-components)
4. [Performance Metrics](#performance-metrics)
5. [Reliability Metrics](#reliability-metrics)
6. [Alert Management](#alert-management)
7. [Health Checks](#health-checks)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

---

## 🎯 Overview

The Pivori Studio Production Monitoring Dashboard provides comprehensive real-time visibility into system performance, reliability, and health. The dashboard integrates Prometheus metrics collection, Grafana visualization, and Alertmanager notifications to ensure production systems operate within defined SLOs.

### Key Features

The monitoring solution delivers the following capabilities:

**Real-time Metrics Collection**: Prometheus scrapes metrics from all microservices at 30-second intervals, collecting over 50 custom metrics including latency percentiles, error rates, and resource utilization.

**Interactive Dashboards**: Grafana provides two primary dashboards—Performance & Reliability for system-wide metrics and Microservices for service-specific analysis—with drill-down capabilities and customizable time ranges.

**Intelligent Alerting**: Alertmanager routes alerts based on severity (critical, warning, info) to appropriate channels including Slack for warnings and PagerDuty for critical incidents.

**Automated Health Checks**: A comprehensive shell script validates system health across Kubernetes, monitoring stack, performance, resources, connectivity, security, and backup components.

---

## 🏗️ Architecture

### Components

The monitoring architecture consists of five primary components working in concert:

| Component | Purpose | Port | Replicas |
|-----------|---------|------|----------|
| **Prometheus** | Metrics collection & storage | 9090 | 1 |
| **Grafana** | Metrics visualization | 3000 | 2 |
| **Alertmanager** | Alert routing & notifications | 9093 | 2 |
| **Node Exporter** | Host metrics | 9100 | Per node |
| **kube-state-metrics** | Kubernetes state metrics | 8080 | 1 |

### Data Flow

```
Microservices (metrics endpoints)
    ↓
Prometheus (scrape & store)
    ↓
Grafana (query & visualize)
    ↓
Alertmanager (route alerts)
    ↓
Slack / PagerDuty (notifications)
```

### Deployment

All monitoring components deploy to the `monitoring` namespace with the following configuration:

**Prometheus**: Deployed as a StatefulSet with persistent storage (50GB), scraping configuration for all services, and alert rule definitions. The service exposes port 9090 internally and includes health check endpoints.

**Grafana**: Deployed as a Deployment with 2 replicas for high availability. Dashboard definitions load from ConfigMaps, datasources configure automatically, and the service exposes port 3000 via LoadBalancer.

**Alertmanager**: Deployed as a Deployment with 2 replicas for redundancy. Configuration includes routing rules, receiver definitions for Slack and PagerDuty, and inhibition rules to prevent alert storms.

---

## 📊 Dashboard Components

### Dashboard 1: Production - Performance & Reliability

This primary dashboard provides system-wide visibility into performance and reliability metrics.

#### Panels

**Uptime Global** (Gauge)
- Displays overall system uptime percentage
- Green: > 99.9%
- Yellow: 99.0-99.9%
- Red: < 99.0%
- Updates every 10 seconds

**Latency Distribution** (Time Series)
- Shows P50, P95, and P99 latency percentiles over time
- Threshold: P95 < 500ms, P99 < 1000ms
- Helps identify performance degradation trends
- 1-hour default view with 10-second refresh

**Request Rate by Service** (Time Series)
- Displays requests per second for each microservice
- Identifies traffic patterns and load distribution
- Useful for capacity planning and anomaly detection
- Stacked view shows aggregate traffic

**Error Rate Trend** (Time Series)
- Tracks 5xx server errors and 4xx client errors separately
- Server errors (5xx) threshold: < 0.1%
- Client errors (4xx) threshold: < 10%
- Helps distinguish between application and user issues

**Memory Usage by Pod** (Time Series)
- Shows memory consumption for each pod
- Threshold: 1.8GB warning, 1.95GB critical
- Identifies memory leaks and inefficient services
- Useful for right-sizing pod requests/limits

**CPU Usage by Pod** (Time Series)
- Displays CPU utilization percentage per pod
- Threshold: 75% warning, 90% critical
- Helps identify CPU-bound services
- Informs HPA scaling decisions

**Active Connections by Service** (Time Series)
- Tracks concurrent connections per service
- Identifies connection pool exhaustion
- Useful for database and cache monitoring
- Helps detect connection leaks

**Request Status Distribution** (Bar Chart)
- Shows 5-minute aggregated requests by status code
- Stacked view: 2xx (green), 4xx (yellow), 5xx (red)
- Provides quick overview of request success distribution
- Useful for identifying sudden error spikes

### Dashboard 2: Microservices - Performance Metrics

This detailed dashboard provides per-service performance analysis.

#### Panels

**Latency by Microservice** (Time Series)
- P95 and P99 latency for each of 15 microservices
- Allows identification of slowest services
- Supports drill-down for root cause analysis
- Compares performance across service groups

**Error Rate by Microservice** (Time Series)
- 5xx error rate percentage for each service
- Identifies services with reliability issues
- Helps prioritize debugging efforts
- Shows error trends over time

**Request Rate by Microservice** (Time Series)
- Requests per second for each service
- Identifies traffic distribution
- Useful for load balancing verification
- Shows traffic spikes and anomalies

---

## 📈 Performance Metrics

### Latency Percentiles

Latency percentiles provide insight into user experience distribution rather than just averages.

**P50 (Median)**: 50% of requests complete faster than this value. For Pivori Studio, P50 typically ranges from 50-100ms for most services.

**P95**: 95% of requests complete faster than this value. The target is P95 < 500ms, ensuring most users experience acceptable performance. When P95 exceeds 500ms, investigate database queries, external API calls, or resource constraints.

**P99**: 99% of requests complete faster than this value. The target is P99 < 1000ms. Values exceeding 1000ms indicate tail latency issues affecting 1% of users, often caused by garbage collection pauses, cache misses, or resource contention.

### Latency Thresholds

| Percentile | Target | Warning | Critical |
|-----------|--------|---------|----------|
| **P50** | < 100ms | 100-200ms | > 200ms |
| **P95** | < 500ms | 500-750ms | > 750ms |
| **P99** | < 1000ms | 1000-1500ms | > 1500ms |

### Query Examples

To query latency metrics in Prometheus:

```promql
# P95 latency across all services
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# P99 latency for specific service
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{service="trading"}[5m])) by (le))

# P95 latency by endpoint
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, endpoint))
```

---

## 🛡️ Reliability Metrics

### Error Rate

Error rate measures the percentage of requests that result in 5xx server errors, indicating application failures.

**Calculation**: `(5xx errors / total requests) * 100`

**Targets**:
- Normal operation: < 0.1%
- Acceptable degradation: 0.1-1%
- Critical: > 1%

### Uptime

Uptime represents the percentage of time services are available and responding without errors.

**Calculation**: `100 - (5xx error rate)`

**Targets**:
- Production: 99.99% (52 minutes downtime/year)
- Acceptable: 99.9% (8.7 hours downtime/year)
- Critical: < 99% (> 87.6 hours downtime/year)

### Service Availability

Individual service availability tracks whether each microservice responds to health checks.

**Health Check Endpoints**:
- Geolocation Service: `http://geolocation:8010/health`
- Trading Service: `http://trading:8040/health`
- Market Data Service: `http://market-data:8050/health`
- All services: `http://{service}:{port}/health`

### Query Examples

```promql
# Overall error rate
(sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) * 100

# Error rate by service
(sum(rate(http_requests_total{status=~"5..", service=~".*"}[5m])) by (service) / 
 sum(rate(http_requests_total{service=~".*"}[5m])) by (service)) * 100

# Uptime percentage
100 - (avg(rate(http_requests_total{status=~"5.."}[5m])) * 100)
```

---

## 🚨 Alert Management

### Alert Severity Levels

Alerts classify into three severity levels with corresponding routing:

**Critical Severity**
- Immediate impact on production
- Routed to Slack #critical-alerts and PagerDuty
- On-call engineer paged immediately
- Requires immediate investigation and remediation
- Examples: Service down, Error rate > 5%, Pod crash looping

**Warning Severity**
- Degraded performance or approaching limits
- Routed to Slack #warnings
- No immediate paging, reviewed during business hours
- Requires investigation within 4 hours
- Examples: P95 latency > 500ms, Memory usage > 1.8GB, Certificate expiring in 7 days

**Info Severity**
- Informational events for awareness
- Routed to Slack #info
- No immediate action required
- Reviewed for trends and patterns
- Examples: High client error rate, Service restart

### Alert Rules

#### Performance Alerts

**HighP95Latency** (Warning)
- Condition: P95 latency > 500ms for 5 minutes
- Action: Investigate database performance, external API latency, or resource constraints
- Dashboard: Performance & Reliability

**CriticalP99Latency** (Critical)
- Condition: P99 latency > 1000ms for 3 minutes
- Action: Immediate investigation required; check resource utilization and query performance
- Dashboard: Performance & Reliability

**ServiceLatencyDegradation** (Warning)
- Condition: Latency increased > 50% compared to 1 hour ago for 10 minutes
- Action: Identify recent changes or increased load
- Dashboard: Microservices Performance

#### Reliability Alerts

**HighErrorRate** (Warning)
- Condition: Error rate > 1% for 5 minutes
- Action: Check application logs, database connectivity, and external service health
- Dashboard: Performance & Reliability

**CriticalErrorRate** (Critical)
- Condition: Error rate > 5% for 2 minutes
- Action: Immediate incident response; page on-call engineer
- Dashboard: Performance & Reliability

**ServiceDown** (Critical)
- Condition: Service fails health check for 1 minute
- Action: Check pod status, logs, and restart if necessary
- Dashboard: Kubernetes cluster status

#### Resource Alerts

**HighMemoryUsage** (Warning)
- Condition: Pod memory > 1.8GB for 5 minutes
- Action: Investigate memory leaks, adjust pod limits, or scale horizontally
- Dashboard: Performance & Reliability

**CriticalMemoryUsage** (Critical)
- Condition: Pod memory > 1.95GB for 2 minutes
- Action: Immediate action required; pod may be OOMKilled
- Dashboard: Performance & Reliability

**HighCPUUsage** (Warning)
- Condition: Pod CPU > 75% for 5 minutes
- Action: Investigate CPU-bound operations, optimize code, or scale horizontally
- Dashboard: Performance & Reliability

#### Availability Alerts

**PodCrashLooping** (Critical)
- Condition: Pod restarts > 0.1 times/minute for 5 minutes
- Action: Check pod logs, configuration, and recent deployments
- Dashboard: Kubernetes cluster status

**NodeNotReady** (Critical)
- Condition: Node not ready for 5 minutes
- Action: SSH to node, check kubelet status, investigate hardware issues
- Dashboard: Kubernetes cluster status

### Alert Response Procedures

#### Critical Alert Response

1. **Acknowledge Alert**: Acknowledge in PagerDuty to prevent duplicate pages
2. **Assess Impact**: Determine scope (single service, multiple services, region)
3. **Gather Information**: Check dashboards, logs, and recent deployments
4. **Implement Fix**: Apply remediation (restart pod, scale up, rollback deployment)
5. **Verify Resolution**: Confirm alert clears and service recovers
6. **Post-Incident**: Document in incident tracking system

#### Warning Alert Response

1. **Review Alert**: Check dashboard and recent metrics
2. **Investigate**: Determine root cause and trend
3. **Plan Action**: Schedule investigation or remediation
4. **Implement Fix**: Apply changes during maintenance window if needed
5. **Monitor**: Verify alert doesn't recur

---

## 🏥 Health Checks

### Automated Health Check Script

The `monitoring-health-checks.sh` script provides comprehensive system validation:

```bash
./scripts/monitoring-health-checks.sh
```

### Health Check Categories

**Kubernetes Health**
- Verifies all nodes are ready
- Checks pod status in production namespace
- Validates cluster API responsiveness

**Monitoring Stack Health**
- Prometheus health and target count
- Grafana API responsiveness
- Alertmanager health and configuration

**Performance Metrics**
- P95 and P99 latency validation
- Error rate within thresholds
- Uptime percentage verification

**Resource Utilization**
- Memory usage across pods
- CPU usage across pods
- Disk space on persistent volumes

**Connectivity**
- PostgreSQL database accessibility
- Redis cache accessibility
- Service health endpoints

**Security**
- Certificate expiration dates
- RBAC policy configuration
- Network policy enforcement

**Backup Status**
- Velero backup completion
- Backup age (< 24 hours)
- Restore capability verification

### Running Health Checks

**Manual Execution**:
```bash
cd /home/ubuntu/Pivori-studio
./scripts/monitoring-health-checks.sh
```

**Scheduled Execution** (via cron):
```bash
# Run health checks every 6 hours
0 */6 * * * /home/ubuntu/Pivori-studio/scripts/monitoring-health-checks.sh >> /var/log/pivori-monitoring/health-checks.log 2>&1
```

**Kubernetes CronJob**:
```bash
kubectl apply -f kubernetes/health-check-cronjob.yaml
```

### Health Check Output

Successful execution produces:
- Color-coded status messages (green for success, yellow for warning, red for error)
- Detailed metrics for each component
- Health report saved to `/var/log/pivori-monitoring/health-report-*.txt`
- Metrics snapshot saved to `/var/log/pivori-monitoring/metrics-*.json`

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### Issue: High P95/P99 Latency

**Symptoms**: Dashboard shows P95 > 500ms or P99 > 1000ms

**Investigation Steps**:
1. Check Microservices dashboard to identify slowest service
2. Review service logs for errors or warnings
3. Check database query performance using `pg_stat_statements`
4. Verify resource utilization (CPU, memory) isn't constrained
5. Check external API response times if applicable

**Solutions**:
- Optimize slow database queries (add indexes, rewrite queries)
- Scale service horizontally (increase replicas)
- Increase pod resource limits if CPU/memory constrained
- Implement caching for frequently accessed data
- Review recent code changes for performance regressions

#### Issue: High Error Rate

**Symptoms**: Dashboard shows error rate > 1%

**Investigation Steps**:
1. Check Microservices dashboard to identify service with errors
2. Review application logs for error messages
3. Check database connectivity and health
4. Verify external service dependencies are accessible
5. Check for recent deployments or configuration changes

**Solutions**:
- Restart affected service pods
- Rollback recent deployment if error rate increased after deployment
- Fix database connection pool exhaustion
- Increase timeout values for external API calls
- Add retry logic with exponential backoff

#### Issue: Pod Memory Exceeding Limits

**Symptoms**: Dashboard shows pod memory > 1.95GB

**Investigation Steps**:
1. Check pod logs for memory allocation patterns
2. Use `kubectl top pods` to verify current usage
3. Check for memory leaks using profiling tools
4. Review recent code changes affecting memory usage
5. Check database connection pool size

**Solutions**:
- Increase pod memory limits in deployment
- Implement memory profiling to find leaks
- Optimize data structures and algorithms
- Reduce connection pool size if excessive
- Implement garbage collection tuning

#### Issue: Prometheus Disk Space Full

**Symptoms**: Prometheus stops collecting metrics, alerts stop firing

**Investigation Steps**:
1. Check Prometheus pod logs
2. Verify persistent volume space: `kubectl exec prometheus-0 -n monitoring -- df -h`
3. Check data retention settings in Prometheus configuration
4. Verify backup process is working

**Solutions**:
- Increase persistent volume size
- Reduce data retention period (default 15 days)
- Delete old data: `kubectl exec prometheus-0 -n monitoring -- rm -rf /prometheus/wal/*`
- Restart Prometheus pod after cleanup

#### Issue: Alerts Not Firing

**Symptoms**: Known issues not triggering alerts

**Investigation Steps**:
1. Verify Alertmanager is running: `kubectl get pods -n monitoring | grep alertmanager`
2. Check Alertmanager configuration: `kubectl get configmap alertmanager-config -n monitoring -o yaml`
3. Verify Slack/PagerDuty webhooks are configured
4. Check Prometheus alert rules: `kubectl get prometheusrule -n monitoring`
5. Query Prometheus for alert status: `curl http://prometheus:9090/api/v1/alerts`

**Solutions**:
- Restart Alertmanager pods
- Update webhook URLs if they changed
- Verify alert rule syntax in PrometheusRule
- Increase alert evaluation interval if needed
- Check Prometheus logs for rule evaluation errors

#### Issue: Grafana Dashboard Not Updating

**Symptoms**: Dashboard shows stale data

**Investigation Steps**:
1. Check Grafana logs: `kubectl logs -n monitoring -l app=grafana`
2. Verify Prometheus datasource connectivity in Grafana UI
3. Check Prometheus is scraping metrics
4. Verify dashboard refresh rate setting

**Solutions**:
- Refresh browser page (Ctrl+Shift+R)
- Increase dashboard refresh rate
- Restart Grafana pods
- Verify Prometheus datasource configuration
- Check Prometheus storage space

---

## 📚 Best Practices

### Monitoring Best Practices

**Define Clear SLOs**: Establish Service Level Objectives for each metric (e.g., P95 < 500ms, uptime > 99.9%) and communicate to stakeholders.

**Alert on Symptoms, Not Causes**: Alert on user-visible symptoms (high latency, errors) rather than internal metrics (CPU usage). This reduces alert fatigue and focuses on impact.

**Use Alert Thresholds Wisely**: Set thresholds based on historical data and business requirements. Too sensitive causes alert fatigue; too loose misses real issues.

**Implement Alert Runbooks**: Create documented procedures for responding to each alert type, including investigation steps and remediation actions.

**Review Alerts Regularly**: Audit alert rules quarterly to remove noisy alerts and add coverage for new services or failure modes.

**Maintain Dashboard Consistency**: Keep dashboard layouts consistent across similar metrics and services for easier interpretation.

**Document Dashboard Panels**: Add descriptions to dashboard panels explaining metrics, thresholds, and interpretation.

### Operational Best Practices

**On-Call Rotation**: Establish clear on-call rotation with defined escalation procedures and handoff processes.

**Incident Response**: Document incident response procedures including assessment, communication, remediation, and post-incident review.

**Capacity Planning**: Use metrics trends to plan capacity growth, identifying services approaching resource limits.

**Performance Optimization**: Use latency distribution data to identify optimization opportunities, focusing on tail latency (P99) improvements.

**Backup Verification**: Regularly test backup restoration to ensure recovery capability in disaster scenarios.

**Security Monitoring**: Monitor for security indicators including failed authentication attempts, unauthorized access patterns, and certificate expiration.

### Metrics Collection Best Practices

**Instrument All Services**: Ensure all microservices expose Prometheus metrics on `/metrics` endpoint with proper labels.

**Use Consistent Labels**: Standardize label names (service, endpoint, method, status) across all services for easier querying.

**Avoid High-Cardinality Labels**: Avoid labels with unbounded values (user IDs, request IDs) that can cause Prometheus memory issues.

**Set Appropriate Scrape Intervals**: Balance between metric freshness (30-second intervals) and storage overhead.

**Implement Metric Retention**: Set appropriate retention periods (15 days default) based on storage capacity and analysis needs.

---

## 📞 Support and Escalation

### Support Channels

- **Slack**: #pivori-monitoring for questions and discussions
- **Email**: monitoring-team@pivori.app
- **On-Call**: PagerDuty for critical incidents
- **Documentation**: Internal wiki for runbooks and procedures

### Escalation Path

1. **Level 1**: Monitoring team (1-hour response)
2. **Level 2**: DevOps team (30-minute response)
3. **Level 3**: Engineering lead (15-minute response)
4. **Level 4**: CTO (5-minute response)

---

## 📋 Appendix

### Useful Commands

```bash
# Check Prometheus targets
curl http://prometheus:9090/api/v1/targets | jq '.data.activeTargets[] | {labels, health}'

# Query specific metric
curl 'http://prometheus:9090/api/v1/query?query=up'

# Get active alerts
curl http://alertmanager:9093/api/v1/alerts | jq '.data[] | {labels, status}'

# Check Grafana datasources
curl -H "Authorization: Bearer $GRAFANA_TOKEN" http://grafana:3000/api/datasources

# View Prometheus configuration
kubectl get configmap -n monitoring prometheus-config -o yaml

# Check alert rule status
kubectl get prometheusrule -n monitoring -o yaml
```

### References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/overview/)
- [Kubernetes Monitoring](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/)

---

**Document Version**: 1.0.0  
**Last Updated**: 2025-11-09  
**Next Review**: 2025-12-09

