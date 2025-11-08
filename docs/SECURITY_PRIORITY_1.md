# 🔐 SÉCURITÉ - PRIORITÉ 1 (CRITIQUE)

**Date:** 2024-01-15  
**Statut:** À Implémenter  
**Timeline:** Semaines 1-2  
**Effort Total:** 76 heures  
**Équipe:** 2-3 DevOps Engineers + 1 Security Lead

---

## 📋 TABLE DES MATIÈRES

1. [Sealed Secrets](#sealed-secrets)
2. [Network Policies](#network-policies)
3. [Image Scanning](#image-scanning)
4. [Audit Logging](#audit-logging)
5. [Implémentation Détaillée](#implémentation-détaillée)
6. [Testing & Validation](#testing--validation)

---

## 🔐 1. SEALED SECRETS

### Objectif
Chiffrer tous les secrets Kubernetes pour éviter le stockage en plaintext.

### Problème Actuel
```yaml
# ❌ MAUVAIS - Secrets en plaintext
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
type: Opaque
data:
  password: bXlwYXNzd29yZA==  # Base64 = plaintext
```

### Solution
```yaml
# ✅ BON - Sealed Secret
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: database-credentials
spec:
  encryptedData:
    password: AgBvB3j4k2l...  # Chiffré avec clé publique
```

### Étapes d'Implémentation

#### Étape 1: Installation (4 heures)

```bash
# 1.1 Ajouter le repo Helm
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

# 1.2 Installer Sealed Secrets
helm install sealed-secrets -n kube-system sealed-secrets/sealed-secrets \
  --set commandArgs="{--update-status}" \
  --wait

# 1.3 Vérifier l'installation
kubectl get pods -n kube-system | grep sealed-secrets
kubectl get secret -n kube-system sealed-secrets-key

# 1.4 Installer kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/kubeseal-0.18.0-linux-amd64.tar.gz
tar xfz kubeseal-0.18.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# 1.5 Vérifier kubeseal
kubeseal --version
```

**Validation:**
```bash
# Vérifier que le pod est running
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Vérifier que la clé de chiffrement existe
kubectl get secret -n kube-system sealed-secrets-key -o yaml
```

#### Étape 2: Migration des Secrets (16 heures)

**Secrets à migrer:**

1. **Database Credentials**
```bash
# Créer un secret plaintext temporaire
kubectl create secret generic db-credentials \
  --from-literal=username=postgres \
  --from-literal=password=YOUR_PASSWORD \
  --from-literal=host=postgresql.rubi-studio.svc.cluster.local \
  --from-literal=port=5432 \
  --from-literal=database=rubi_studio \
  --dry-run=client -o yaml > db-secret.yaml

# Sceller le secret
kubeseal -f db-secret.yaml -w db-secret-sealed.yaml

# Appliquer le sealed secret
kubectl apply -f db-secret-sealed.yaml

# Supprimer le plaintext
rm db-secret.yaml
```

2. **Redis Credentials**
```bash
kubectl create secret generic redis-credentials \
  --from-literal=password=YOUR_REDIS_PASSWORD \
  --from-literal=host=redis.rubi-studio.svc.cluster.local \
  --from-literal=port=6379 \
  --dry-run=client -o yaml | kubeseal -f - -w redis-secret-sealed.yaml

kubectl apply -f redis-secret-sealed.yaml
```

3. **API Keys (Stripe, PayPal)**
```bash
kubectl create secret generic stripe-api-key \
  --from-literal=key=sk_live_YOUR_KEY \
  --dry-run=client -o yaml | kubeseal -f - -w stripe-secret-sealed.yaml

kubectl apply -f stripe-secret-sealed.yaml

# Répéter pour PayPal, etc.
```

4. **JWT Secrets**
```bash
kubectl create secret generic jwt-secret \
  --from-literal=secret=YOUR_JWT_SECRET \
  --from-literal=algorithm=HS256 \
  --dry-run=client -o yaml | kubeseal -f - -w jwt-secret-sealed.yaml

kubectl apply -f jwt-secret-sealed.yaml
```

5. **SMTP Credentials**
```bash
kubectl create secret generic smtp-credentials \
  --from-literal=username=YOUR_EMAIL \
  --from-literal=password=YOUR_PASSWORD \
  --from-literal=host=smtp.gmail.com \
  --from-literal=port=587 \
  --dry-run=client -o yaml | kubeseal -f - -w smtp-secret-sealed.yaml

kubectl apply -f smtp-secret-sealed.yaml
```

6. **Slack Webhooks**
```bash
kubectl create secret generic slack-webhooks \
  --from-literal=alerts-channel=https://hooks.slack.com/services/... \
  --from-literal=critical-channel=https://hooks.slack.com/services/... \
  --dry-run=client -o yaml | kubeseal -f - -w slack-secret-sealed.yaml

kubectl apply -f slack-secret-sealed.yaml
```

7. **PagerDuty Keys**
```bash
kubectl create secret generic pagerduty-keys \
  --from-literal=service-key=YOUR_KEY \
  --from-literal=api-token=YOUR_TOKEN \
  --dry-run=client -o yaml | kubeseal -f - -w pagerduty-secret-sealed.yaml

kubectl apply -f pagerduty-secret-sealed.yaml
```

8. **GitHub Tokens**
```bash
kubectl create secret generic github-token \
  --from-literal=token=ghp_YOUR_TOKEN \
  --dry-run=client -o yaml | kubeseal -f - -w github-secret-sealed.yaml

kubectl apply -f github-secret-sealed.yaml
```

**Checklist de migration:**
- [ ] Database credentials
- [ ] Redis credentials
- [ ] Stripe API key
- [ ] PayPal credentials
- [ ] JWT secrets
- [ ] SMTP credentials
- [ ] Slack webhooks
- [ ] PagerDuty keys
- [ ] GitHub tokens
- [ ] Tous les autres secrets

#### Étape 3: Utilisation dans les Deployments (4 heures)

```yaml
# Avant (❌ Mauvais)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: geolocation
spec:
  template:
    spec:
      containers:
      - name: geolocation
        env:
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials  # Secret plaintext
              key: password

---
# Après (✅ Bon)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: geolocation
spec:
  template:
    spec:
      containers:
      - name: geolocation
        env:
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials  # Sealed Secret
              key: password
```

**Note:** Le code reste identique! Kubernetes déchiffre automatiquement les Sealed Secrets.

#### Étape 4: Backup de la Clé de Chiffrement (2 heures)

```bash
# Exporter la clé de chiffrement
kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml

# Stocker de manière sécurisée (Vault, 1Password, etc.)
# NE PAS commiter dans Git!

# Vérifier le backup
kubectl get secret -n kube-system sealed-secrets-key -o yaml | diff - sealed-secrets-key-backup.yaml
```

**Sécurité:**
- [ ] Clé sauvegardée
- [ ] Stockée de manière sécurisée
- [ ] Accès limité
- [ ] Rotation planifiée

---

## 🛡️ 2. NETWORK POLICIES

### Objectif
Implémenter une stratégie de sécurité réseau avec deny-all par défaut.

### Problème Actuel
```
Tous les pods peuvent communiquer avec tous les autres pods
Pas de restriction de trafic réseau
Risque de propagation d'attaques
```

### Solution
```
1. Deny-all par défaut
2. Allow DNS
3. Allow inter-service communication
4. Allow database access
5. Allow monitoring
6. Allow external APIs
```

### Étapes d'Implémentation

#### Étape 1: Audit des Flux Réseau (8 heures)

```bash
# 1.1 Documenter les communications actuelles
kubectl logs -n rubi-studio -l app=geolocation --tail=100 | grep -i "connecting\|request"

# 1.2 Analyser les connexions réseau
kubectl exec -it geolocation-pod -- netstat -an

# 1.3 Utiliser Cilium pour visualiser les flux
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.11/install/kubernetes/quick-install.yaml

# 1.4 Vérifier les flux avec Hubble
cilium hubble ui
```

**Flux à documenter:**

| Source | Destination | Port | Protocole | Raison |
|--------|-------------|------|-----------|--------|
| geolocation | postgresql | 5432 | TCP | Database |
| routing | postgresql | 5432 | TCP | Database |
| trading | market-data | 8000 | TCP | Service call |
| * | prometheus | 9090 | TCP | Metrics |
| * | redis | 6379 | TCP | Cache |
| * | kube-dns | 53 | UDP | DNS |

#### Étape 2: Implémentation Deny-All (8 heures)

```yaml
# 1. Deny-all par défaut pour tout le namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: rubi-studio
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Validation:**
```bash
# Après cette étape, RIEN ne fonctionne!
# Les pods ne peuvent pas communiquer
# Les pods ne peuvent pas accéder à Internet
```

#### Étape 3: Allow DNS (4 heures)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: rubi-studio
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  # Allow DNS to kube-system namespace
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

**Validation:**
```bash
# Tester DNS
kubectl exec -it geolocation-pod -- nslookup kubernetes.default
```

#### Étape 4: Allow Inter-Service Communication (8 heures)

```yaml
# 4.1 Allow ingress from other pods in the same namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-inter-service
  namespace: rubi-studio
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8000

# 4.2 Allow egress to other pods in the same namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-inter-service
  namespace: rubi-studio
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8000
```

**Validation:**
```bash
# Tester la communication inter-service
kubectl exec -it geolocation-pod -- curl http://routing:8000/health
```

#### Étape 5: Allow Database Access (4 heures)

```yaml
# 5.1 PostgreSQL
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-postgresql
  namespace: rubi-studio
spec:
  podSelector:
    matchLabels:
      app: postgresql
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: rubi-studio
    ports:
    - protocol: TCP
      port: 5432

# 5.2 Redis
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-redis
  namespace: rubi-studio
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: rubi-studio
    ports:
    - protocol: TCP
      port: 6379
```

**Validation:**
```bash
# Tester la connexion à PostgreSQL
kubectl exec -it geolocation-pod -- psql -h postgresql -U postgres -c "SELECT 1"

# Tester la connexion à Redis
kubectl exec -it geolocation-pod -- redis-cli -h redis ping
```

#### Étape 6: Allow Monitoring (4 heures)

```yaml
# Allow Prometheus scraping
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus
  namespace: rubi-studio
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
    - protocol: TCP
      port: 8001  # Metrics port
```

**Validation:**
```bash
# Tester l'accès Prometheus
kubectl exec -it prometheus-pod -n monitoring -- curl http://geolocation:8001/metrics
```

#### Étape 7: Allow External APIs (4 heures)

```yaml
# Allow egress to external APIs
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-apis
  namespace: rubi-studio
spec:
  podSelector:
    matchLabels:
      requires-external-api: "true"
  policyTypes:
  - Egress
  egress:
  # Allow to external HTTPS
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
  # Allow to external HTTP
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 80
```

**Validation:**
```bash
# Tester l'accès à une API externe
kubectl exec -it payment-pod -- curl https://api.stripe.com/v1/charges
```

### Network Policies Complètes

```yaml
# Fichier: kubernetes/network-policies.yaml

---
# 1. Deny all ingress and egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: rubi-studio
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# 2. Allow DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: rubi-studio
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53

---
# 3. Allow inter-service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-inter-service
  namespace: rubi-studio
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8000

---
# 4. Allow database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-database
  namespace: rubi-studio
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379

---
# 5. Allow monitoring
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: rubi-studio
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8001

---
# 6. Allow external APIs
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-apis
  namespace: rubi-studio
spec:
  podSelector:
    matchLabels:
      requires-external-api: "true"
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

**Appliquer les policies:**
```bash
kubectl apply -f kubernetes/network-policies.yaml
```

---

## 📸 3. IMAGE SCANNING

### Objectif
Scanner les images Docker pour détecter les vulnérabilités avant le déploiement.

### Problème Actuel
```
Pas de scan de vulnérabilités
Images potentiellement vulnérables en production
Pas de visibilité sur les risques
```

### Solution
Intégrer Trivy dans la pipeline CI/CD GitHub Actions.

### Étapes d'Implémentation

#### Étape 1: Configuration GitHub Actions (8 heures)

```yaml
# .github/workflows/scan-images.yml
name: Scan Docker Images

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
  schedule:
    - cron: '0 2 * * *'  # Daily scan at 2 AM

jobs:
  scan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: 
          - geolocation
          - routing
          - proximity
          - trading
          - market-data
          - payment
          - iptv
          - audio
          - live
          - game
          - leaderboard
          - reward
          - document-scan
          - watermark
          - security
    
    steps:
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ghcr.io/rubi-studio/${{ matrix.service }}:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results-${{ matrix.service }}.sarif'
    
    - name: Upload Trivy results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results-${{ matrix.service }}.sarif'
    
    - name: Fail if CRITICAL or HIGH vulnerabilities found
      run: |
        trivy image --severity CRITICAL,HIGH \
          --exit-code 1 \
          ghcr.io/rubi-studio/${{ matrix.service }}:${{ github.sha }}
    
    - name: Generate vulnerability report
      if: always()
      run: |
        trivy image --severity CRITICAL,HIGH,MEDIUM \
          --format json \
          ghcr.io/rubi-studio/${{ matrix.service }}:${{ github.sha }} \
          > trivy-report-${{ matrix.service }}.json
    
    - name: Upload vulnerability report
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: trivy-reports
        path: trivy-report-*.json
```

#### Étape 2: Configuration Locale (4 heures)

```bash
# 2.1 Installer Trivy
wget https://github.com/aquasecurity/trivy/releases/download/v0.37.0/trivy_0.37.0_Linux-64bit.tar.gz
tar zxvf trivy_0.37.0_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/

# 2.2 Vérifier l'installation
trivy version

# 2.3 Mettre à jour la base de données
trivy image --download-db-only

# 2.4 Scanner une image localement
trivy image ghcr.io/rubi-studio/geolocation:latest
```

#### Étape 3: Politique de Sécurité (4 heures)

```yaml
# .trivyignore
# Format: CVE-ID ou Package name
# Exemple de vulnérabilités acceptées avec justification

# CVE-2021-12345: Accepted - Mitigated by WAF
CVE-2021-12345

# CVE-2021-54321: Accepted - No impact on our usage
CVE-2021-54321
```

**Politique:**
- CRITICAL: Bloquer le build (exit code 1)
- HIGH: Bloquer le build (exit code 1)
- MEDIUM: Warning, permettre avec approbation
- LOW: Permettre

#### Étape 4: Scan des Images Existantes (4 heures)

```bash
# Créer un script de scan
cat > scan-all-images.sh << 'EOF'
#!/bin/bash

SERVICES=(
  "geolocation" "routing" "proximity"
  "trading" "market-data" "payment"
  "iptv" "audio" "live"
  "game" "leaderboard" "reward"
  "document-scan" "watermark" "security"
)

mkdir -p scan-reports

for service in "${SERVICES[@]}"; do
  echo "Scanning $service..."
  trivy image \
    --format json \
    --output scan-reports/$service.json \
    ghcr.io/rubi-studio/$service:latest
done

echo "Scan complete! Reports in scan-reports/"
EOF

chmod +x scan-all-images.sh
./scan-all-images.sh
```

**Analyser les résultats:**
```bash
# Compter les vulnérabilités
for file in scan-reports/*.json; do
  echo "=== $(basename $file) ==="
  jq '.Results[] | .Vulnerabilities | length' $file
done
```

---

## 📝 4. AUDIT LOGGING

### Objectif
Enregistrer toutes les actions importantes pour l'audit et la conformité.

### Problème Actuel
```
Pas d'audit logging
Pas de traçabilité des actions
Impossible de détecter les accès non autorisés
```

### Solution
Activer l'audit logging Kubernetes et intégrer avec ELK Stack.

### Étapes d'Implémentation

#### Étape 1: Configuration Kubernetes Audit (8 heures)

```yaml
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log all requests at Metadata level
- level: Metadata
  omitStages:
  - RequestReceived

# Log pod exec at RequestResponse level
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]
  resources: ["pods", "pods/exec", "pods/log"]

# Log secret access
- level: Metadata
  resources: ["secrets"]
  omitStages:
  - RequestReceived

# Log RBAC changes
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]

# Log service account changes
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]
  resources: ["serviceaccounts"]

# Default rule
- level: Metadata
  omitStages:
  - RequestReceived
```

**Appliquer la configuration:**
```bash
# 1. Copier le fichier de policy
sudo cp audit-policy.yaml /etc/kubernetes/

# 2. Modifier le kube-apiserver manifest
sudo nano /etc/kubernetes/manifests/kube-apiserver.yaml

# Ajouter les arguments:
# --audit-policy-file=/etc/kubernetes/audit-policy.yaml
# --audit-log-maxage=30
# --audit-log-maxbackup=10
# --audit-log-maxsize=100

# 3. Vérifier que le kube-apiserver redémarre
kubectl get pods -n kube-system | grep kube-apiserver
```

#### Étape 2: Intégration ELK Stack (8 heures)

```yaml
# Filebeat pour logs d'audit
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: monitoring
data:
  filebeat.yml: |
    filebeat.inputs:
    - type: log
      enabled: true
      paths:
        - /var/log/kubernetes/audit.log
      json.message_key: message
      json.keys_under_root: true
      json.add_error_key: true
    
    processors:
      - add_kubernetes_metadata:
          in_cluster: true
      - add_host_metadata: ~
    
    output.elasticsearch:
      hosts: ["elasticsearch:9200"]
      index: "audit-logs-%{+yyyy.MM.dd}"
      username: "${ELASTICSEARCH_USERNAME}"
      password: "${ELASTICSEARCH_PASSWORD}"
    
    logging.level: info
    logging.to_files: true
    logging.files:
      path: /var/log/filebeat
      name: filebeat
      keepfiles: 7
      permissions: 0644

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: filebeat
  template:
    metadata:
      labels:
        app: filebeat
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat:8.0.0
        env:
        - name: ELASTICSEARCH_USERNAME
          valueFrom:
            secretKeyRef:
              name: elasticsearch-credentials
              key: username
        - name: ELASTICSEARCH_PASSWORD
          valueFrom:
            secretKeyRef:
              name: elasticsearch-credentials
              key: password
        volumeMounts:
        - name: config
          mountPath: /etc/filebeat
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: filebeat-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

#### Étape 3: Kibana Dashboards (4 heures)

```json
{
  "dashboard": {
    "title": "Kubernetes Audit Logs",
    "panels": [
      {
        "title": "Audit Events by Type",
        "type": "pie",
        "query": "verb:*"
      },
      {
        "title": "Failed Authentications",
        "type": "table",
        "query": "status.code:401 OR status.code:403"
      },
      {
        "title": "Secret Access",
        "type": "timeline",
        "query": "objectRef.resource:secrets"
      },
      {
        "title": "RBAC Changes",
        "type": "table",
        "query": "objectRef.resource:(roles OR rolebindings OR clusterroles OR clusterrolebindings)"
      }
    ]
  }
}
```

---

## 🧪 IMPLÉMENTATION DÉTAILLÉE

### Timeline Détaillée

**Jour 1-3: Sealed Secrets**
- Jour 1: Installation (4h)
- Jour 2: Migration des secrets (8h)
- Jour 3: Utilisation dans deployments (4h)

**Jour 4-7: Network Policies**
- Jour 4: Audit des flux (8h)
- Jour 5-6: Implémentation (8h)
- Jour 7: Testing (8h)

**Jour 8-10: Image Scanning**
- Jour 8: Configuration CI/CD (8h)
- Jour 9: Configuration locale (4h)
- Jour 10: Scan des images (4h)

**Jour 11-14: Audit Logging**
- Jour 11-12: Configuration Kubernetes (8h)
- Jour 13-14: Intégration ELK (8h)

---

## ✅ TESTING & VALIDATION

### Test 1: Sealed Secrets

```bash
# Vérifier qu'un secret est chiffré
kubectl get sealedsecret db-credentials -o yaml | grep encryptedData

# Vérifier qu'un pod peut accéder au secret
kubectl exec -it geolocation-pod -- env | grep DATABASE_PASSWORD

# Vérifier que le secret n'est pas en plaintext dans etcd
kubectl get secret db-credentials -o yaml | grep password
```

### Test 2: Network Policies

```bash
# Test 1: Deny-all fonctionne
kubectl run test-pod --image=busybox --rm -it -- sh
# Essayer de ping un autre pod - devrait échouer

# Test 2: DNS fonctionne
nslookup kubernetes.default

# Test 3: Communication inter-service fonctionne
curl http://geolocation:8000/health

# Test 4: Accès DB fonctionne
psql -h postgresql -U postgres -d rubi_studio -c "SELECT 1"

# Test 5: Accès Prometheus fonctionne
curl http://prometheus:9090/api/v1/query
```

### Test 3: Image Scanning

```bash
# Tester Trivy localement
trivy image ghcr.io/rubi-studio/geolocation:latest

# Vérifier que les résultats sont dans GitHub Security
# Aller à: https://github.com/rubi-studio/services/security/code-scanning
```

### Test 4: Audit Logging

```bash
# Vérifier que les logs sont collectés
kubectl logs -n monitoring -l app=filebeat | tail -20

# Vérifier dans Kibana
# Aller à: https://kibana.example.com
# Index: audit-logs-*
```

---

## 📋 CHECKLIST FINALE

- [ ] Sealed Secrets installé
- [ ] Tous les secrets migrés
- [ ] Network Policies appliquées
- [ ] Image Scanning en place
- [ ] Audit Logging activé
- [ ] Tests réussis
- [ ] Documentation mise à jour
- [ ] Équipe formée

---

**Fin de la documentation Sécurité Priorité 1**

