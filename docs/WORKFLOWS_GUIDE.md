# 🚀 GitHub Workflows Guide - Pivori Studio

Complete guide to GitHub Actions workflows for Pivori Studio microservices.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Workflows](#workflows)
3. [Custom Actions](#custom-actions)
4. [Usage Examples](#usage-examples)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

### Architecture

```
GitHub Actions Pipeline
│
├─ Build Services (Parallel - 15 services)
│  └─ Docker images
│
├─ Test Suite (Parallel - Unit + Integration)
│  └─ Coverage reports
│
├─ Security Scan (Scheduled + On-demand)
│  └─ Vulnerability reports
│
└─ Deploy to Kubernetes (Manual + Auto)
   └─ Helm deployments
```

### Key Features

- ✅ **Parallel Builds**: All 15 services built simultaneously
- ✅ **Comprehensive Testing**: Unit + Integration + Smoke tests
- ✅ **Security First**: Trivy + Safety + CodeQL
- ✅ **Automated Deployment**: Helm + Kubernetes
- ✅ **Reusable Actions**: Custom actions for common tasks
- ✅ **Environment Management**: Staging + Production

---

## 📦 Workflows

### 1. Build Services

**File**: `.github/workflows/build-services.yml`

**Trigger**:
- Push to `main` or `develop`
- Changes in `services/**`
- Manual trigger

**Jobs**:
- Build 15 services in parallel
- Create Docker images
- Upload artifacts

**Matrix Strategy**:
```yaml
services: [geolocation, routing, proximity, trading, market-data, 
           payment, iptv, audio, live, game, leaderboard, reward, 
           document-scan, watermark, security]
```

**Outputs**:
- Docker images (tar format)
- Build logs
- Artifact retention: 1 day

**Example Output**:
```
✅ geolocation:latest
✅ routing:latest
✅ proximity:latest
... (12 more services)
```

---

### 2. Deploy to Kubernetes

**File**: `.github/workflows/deploy-kubernetes.yml`

**Trigger**:
- Push to `main`
- Changes in `services/**`, `frontend/**`, `kubernetes/**`
- Manual workflow dispatch

**Manual Inputs**:
```yaml
environment:
  - staging (default)
  - production
```

**Jobs**:
1. Setup kubectl
2. Deploy all services with Helm
3. Verify deployments
4. Check pod status

**Helm Deployment**:
```bash
helm upgrade --install <service> kubernetes/helm/service-template/ \
  --values kubernetes/helm/<service>/values.yaml \
  -n pivori-production
```

**Verification**:
```bash
kubectl rollout status deployment/geolocation -n pivori-production
kubectl get pods -n pivori-production
```

---

### 3. Test Suite

**File**: `.github/workflows/test-suite.yml`

**Trigger**:
- Push to `main` or `develop`
- Pull requests

**Services**:
- PostgreSQL 15 (test database)
- Redis 7 (cache)

**Test Coverage**:
- Unit tests
- Integration tests
- Coverage reports

**Parallel Execution**:
```bash
for service in services/*/; do
  pytest tests/ -v --cov=app
done
```

**Outputs**:
- Coverage reports (Codecov)
- Test results
- Failure notifications

---

### 4. Security Scan

**File**: `.github/workflows/security-scan.yml`

**Trigger**:
- Push to `main`
- Daily at 2 AM UTC
- Manual trigger

**Scans**:
1. **Trivy**: Filesystem vulnerability scanning
   - Docker images
   - Dependencies
   - Configuration files

2. **Safety**: Python dependency vulnerabilities
   - All requirements.txt files
   - Known CVEs

3. **CodeQL**: Code analysis
   - Security issues
   - Code quality

**Outputs**:
- SARIF format (GitHub Security tab)
- Vulnerability reports
- Remediation suggestions

---

## 🔧 Custom Actions

### 1. Build Service Action

**File**: `.github/actions/build-service/action.yml`

**Inputs**:
```yaml
service-name:
  description: Name of the service
  required: true
registry:
  description: Docker registry
  default: docker.io
```

**Outputs**:
```yaml
image-tag:
  description: Built image tag
```

**Usage**:
```yaml
- uses: ./.github/actions/build-service
  with:
    service-name: geolocation
    registry: ghcr.io
```

**Example**:
```bash
docker build -t ghcr.io/pivori/geolocation:latest services/geolocation/
```

---

### 2. Deploy Helm Action

**File**: `.github/actions/deploy-helm/action.yml`

**Inputs**:
```yaml
service-name:
  description: Service to deploy
  required: true
namespace:
  description: Kubernetes namespace
  default: pivori-production
values-file:
  description: Path to values.yaml
```

**Usage**:
```yaml
- uses: ./.github/actions/deploy-helm
  with:
    service-name: geolocation
    namespace: pivori-staging
```

**Example**:
```bash
helm upgrade --install geolocation kubernetes/helm/service-template/ \
  --values kubernetes/helm/geolocation/values.yaml \
  -n pivori-staging
```

---

### 3. Run Tests Action

**File**: `.github/actions/run-tests/action.yml`

**Inputs**:
```yaml
service-name:
  description: Service to test
  required: true
test-type:
  description: unit | integration | all
  default: all
```

**Usage**:
```yaml
- uses: ./.github/actions/run-tests
  with:
    service-name: geolocation
    test-type: unit
```

**Example**:
```bash
cd services/geolocation
pip install -r requirements.txt
pytest tests/unit/ -v --cov=app
```

---

## 📖 Usage Examples

### Example 1: Build and Deploy Single Service

```yaml
name: Build and Deploy Service

on:
  push:
    branches: [main]
    paths:
      - 'services/geolocation/**'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build
        uses: ./.github/actions/build-service
        with:
          service-name: geolocation
      
      - name: Deploy
        uses: ./.github/actions/deploy-helm
        with:
          service-name: geolocation
```

### Example 2: Run Tests for Multiple Services

```yaml
name: Test All Services

on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [geolocation, routing, trading]
    steps:
      - uses: actions/checkout@v3
      
      - name: Test ${{ matrix.service }}
        uses: ./.github/actions/run-tests
        with:
          service-name: ${{ matrix.service }}
          test-type: all
```

### Example 3: Manual Deployment to Production

```bash
# Via GitHub UI:
1. Go to Actions
2. Select "Deploy to Kubernetes"
3. Click "Run workflow"
4. Select "production"
5. Confirm
```

---

## ✅ Best Practices

### 1. Workflow Design

- ✅ Use matrix strategy for parallel execution
- ✅ Separate concerns (build, test, deploy)
- ✅ Use custom actions for reusability
- ✅ Implement proper error handling

### 2. Security

- ✅ Use secrets for sensitive data
- ✅ Run security scans regularly
- ✅ Limit workflow permissions
- ✅ Audit workflow logs

### 3. Performance

- ✅ Cache dependencies
- ✅ Use parallel jobs
- ✅ Optimize Docker builds
- ✅ Clean up artifacts

### 4. Monitoring

- ✅ Set up notifications
- ✅ Track workflow metrics
- ✅ Monitor deployment status
- ✅ Log all operations

---

## 🔍 Troubleshooting

### Issue: Workflow fails to trigger

**Solution**:
```yaml
# Check trigger conditions
on:
  push:
    branches: [main]
    paths:
      - 'services/**'  # Only triggers on path changes
```

### Issue: Docker build fails

**Solution**:
```bash
# Check Dockerfile syntax
docker build -t test services/geolocation/

# Check dependencies
pip install -r services/geolocation/requirements.txt
```

### Issue: Kubernetes deployment fails

**Solution**:
```bash
# Verify Helm chart
helm lint kubernetes/helm/service-template/

# Check values
helm template geolocation kubernetes/helm/service-template/ \
  --values kubernetes/helm/geolocation/values.yaml
```

### Issue: Tests timeout

**Solution**:
```yaml
# Increase timeout
timeout-minutes: 30

# Or optimize tests
pytest tests/ -n auto  # Parallel execution
```

---

## 📊 Monitoring

### GitHub Actions Dashboard

```
Settings → Actions → General
├─ Workflow permissions
├─ Artifact retention
└─ Log retention
```

### Workflow Metrics

```
Actions → All workflows
├─ Success rate
├─ Average duration
└─ Cost
```

### Deployment Status

```
kubectl get deployments -n pivori-production
kubectl rollout history deployment/geolocation -n pivori-production
```

---

## 🚀 Next Steps

1. ✅ Configure secrets (GitHub UI)
2. ✅ Set up notifications (Slack, Email)
3. ✅ Configure artifact retention
4. ✅ Set up branch protection rules
5. ✅ Monitor workflow execution

---

**Status**: Production-Ready ✅

