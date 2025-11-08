# 🚀 DEPLOYMENT GUIDE - EXPERT

**Niveau:** Expert Qualifié Avancé  
**Date:** 2025-11-08  
**Statut:** Production-Ready  
**Version:** 1.0

---

## 📋 TABLE DES MATIÈRES

1. [Prérequis](#prérequis)
2. [Déploiement Local](#déploiement-local)
3. [Déploiement Staging](#déploiement-staging)
4. [Déploiement Production](#déploiement-production)
5. [Vérification Post-Déploiement](#vérification-post-déploiement)
6. [Rollback](#rollback)

---

## ✅ PRÉREQUIS

### Logiciels Requis

```bash
# Vérifier les versions
docker --version          # >= 20.10
docker-compose --version  # >= 1.29
kubectl version           # >= 1.24
helm version              # >= 3.10
git --version             # >= 2.30
```

### Accès Requis

- [ ] Accès GitHub (SSH key configurée)
- [ ] Accès Docker Registry (credentials)
- [ ] Accès Kubernetes cluster
- [ ] Accès aux secrets GitHub
- [ ] Permissions administrateur

### Espace Disque Requis

```
Local:     10 GB (code + images Docker)
Staging:   50 GB (données + backups)
Production: 500 GB (données + backups + archives)
```

---

## 🏠 DÉPLOIEMENT LOCAL

### Étape 1: Cloner le Repository

```bash
# Cloner
git clone https://github.com/pivori-app/Pivori-studio.git
cd Pivori-studio

# Vérifier la branche
git branch -a
git checkout main
```

### Étape 2: Configurer les Variables d'Environnement

```bash
# Créer le fichier .env
cat > .env << 'EOF'
# Environnement
ENVIRONMENT=local
DEBUG=true

# Backup
BACKUP_STORAGE_PATH=/backups
BACKUP_RETENTION_DAYS=30
BACKUP_COMPRESSION_LEVEL=9

# Services
GEOLOCATION_PORT=8010
ROUTING_PORT=8020
PROXIMITY_PORT=8030

# Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=pivori
POSTGRES_USER=pivori
POSTGRES_PASSWORD=changeme

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# Monitoring
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
JAEGER_PORT=16686
EOF

# Charger les variables
source .env
```

### Étape 3: Démarrer les Services Locaux

```bash
# Démarrer Docker Compose
cd services
docker-compose up -d

# Vérifier le statut
docker-compose ps

# Vérifier les logs
docker-compose logs -f geolocation
```

### Étape 4: Vérifier la Connectivité

```bash
# Tester les services
curl http://localhost:8010/health
curl http://localhost:8020/health
curl http://localhost:8030/health

# Accéder aux dashboards
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000
# Jaeger: http://localhost:16686
```

### Étape 5: Exécuter les Tests

```bash
# Tests unitaires
bash scripts/backup/run-tests.sh unit

# Tests d'intégrité
bash scripts/backup/run-tests.sh integration

# Tous les tests
bash scripts/backup/run-tests.sh all
```

---

## 🏢 DÉPLOIEMENT STAGING

### Étape 1: Préparer l'Environnement Staging

```bash
# Créer le namespace
kubectl create namespace pivori-staging

# Créer les secrets
kubectl create secret generic backup-secrets \
  --from-literal=encryption-key=$BACKUP_ENCRYPTION_KEY \
  -n pivori-staging

kubectl create secret generic slack-secrets \
  --from-literal=webhook-url=$SLACK_WEBHOOK_URL \
  -n pivori-staging
```

### Étape 2: Déployer avec Helm

```bash
# Ajouter le repository Helm
helm repo add pivori https://charts.pivori.app
helm repo update

# Déployer tous les services
for service in geolocation routing proximity trading market-data payment iptv audio live game leaderboard reward document-scan watermark security; do
  helm install $service ./helm/$service \
    -n pivori-staging \
    -f helm/$service/values-staging.yaml
done

# Vérifier le déploiement
kubectl get pods -n pivori-staging
kubectl get svc -n pivori-staging
```

### Étape 3: Configurer Istio

```bash
# Installer Istio
kubectl apply -f kubernetes/istio-setup.yaml

# Configurer les routes
kubectl apply -f kubernetes/istio-virtualservices.yaml

# Vérifier
kubectl get virtualservices -n pivori-staging
```

### Étape 4: Déployer Monitoring

```bash
# Déployer Prometheus
kubectl apply -f kubernetes/monitoring-stack.yaml

# Déployer Grafana
kubectl apply -f kubernetes/grafana-setup.yaml

# Vérifier
kubectl get pods -n monitoring
```

### Étape 5: Vérifier le Déploiement

```bash
# Vérifier les pods
kubectl get pods -n pivori-staging -w

# Vérifier les services
kubectl get svc -n pivori-staging

# Vérifier les logs
kubectl logs -f deployment/geolocation -n pivori-staging

# Tester les endpoints
kubectl port-forward svc/geolocation 8010:8010 -n pivori-staging
curl http://localhost:8010/health
```

---

## 🏭 DÉPLOIEMENT PRODUCTION

### Étape 1: Préparer la Production

```bash
# Créer le namespace
kubectl create namespace pivori-production

# Créer les secrets
kubectl create secret generic backup-secrets \
  --from-literal=encryption-key=$BACKUP_ENCRYPTION_KEY \
  -n pivori-production

kubectl create secret generic slack-secrets \
  --from-literal=webhook-url=$SLACK_WEBHOOK_URL \
  -n pivori-production

# Activer les policies de sécurité
kubectl apply -f kubernetes/network-policies.yaml -n pivori-production
kubectl apply -f kubernetes/pod-security-policies.yaml -n pivori-production
```

### Étape 2: Déployer les Services

```bash
# Déployer avec Helm
for service in geolocation routing proximity trading market-data payment iptv audio live game leaderboard reward document-scan watermark security; do
  helm install $service ./helm/$service \
    -n pivori-production \
    -f helm/$service/values-production.yaml \
    --wait \
    --timeout 5m
done

# Vérifier
kubectl get pods -n pivori-production
```

### Étape 3: Configurer l'Infrastructure

```bash
# Déployer Kong API Gateway
kubectl apply -f kubernetes/kong-setup.yaml -n pivori-production

# Déployer Istio
kubectl apply -f kubernetes/istio-setup.yaml

# Configurer les routes
kubectl apply -f kubernetes/istio-virtualservices.yaml
```

### Étape 4: Activer le Monitoring

```bash
# Déployer Prometheus
kubectl apply -f kubernetes/monitoring-stack.yaml -n monitoring

# Déployer Grafana
kubectl apply -f kubernetes/grafana-setup.yaml -n monitoring

# Déployer Alertmanager
kubectl apply -f kubernetes/alertmanager-setup.yaml -n monitoring

# Vérifier
kubectl get pods -n monitoring
```

### Étape 5: Configurer les Backups Automatisés

```bash
# Créer le CronJob de sauvegarde
cat > kubernetes/backup-cronjob.yaml << 'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-complete
  namespace: pivori-production
spec:
  schedule: "0 2 * * 0"  # Dimanche 2h UTC
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: pivori-studio/backup:latest
            command: ["bash", "scripts/backup/backup-scripts-expert.sh", "backup_complete"]
          restartPolicy: OnFailure
EOF

kubectl apply -f kubernetes/backup-cronjob.yaml
```

---

## ✅ VÉRIFICATION POST-DÉPLOIEMENT

### Checklist de Vérification

```bash
# 1. Vérifier les pods
kubectl get pods -n pivori-production
# Tous les pods doivent être en Running

# 2. Vérifier les services
kubectl get svc -n pivori-production
# Tous les services doivent avoir une IP

# 3. Vérifier les endpoints
kubectl get endpoints -n pivori-production
# Tous les endpoints doivent être prêts

# 4. Vérifier les logs
kubectl logs -f deployment/geolocation -n pivori-production
# Pas d'erreurs critiques

# 5. Tester les endpoints
kubectl port-forward svc/geolocation 8010:8010 -n pivori-production
curl http://localhost:8010/health
# Doit retourner: {"status": "healthy"}

# 6. Vérifier le monitoring
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Accéder à: http://localhost:9090

# 7. Vérifier les alertes
kubectl port-forward svc/alertmanager 9093:9093 -n monitoring
# Accéder à: http://localhost:9093

# 8. Vérifier les backups
kubectl get cronjobs -n pivori-production
# Le backup-complete doit être présent
```

### Tests de Santé

```bash
# Test de connectivité
bash scripts/backup/test-connectivity.sh

# Test de performance
bash scripts/backup/test-performance.sh

# Test de sécurité
bash scripts/backup/test-security.sh

# Test de restauration
bash scripts/backup/test-restore.sh
```

---

## 🔄 ROLLBACK

### Rollback Helm

```bash
# Voir l'historique
helm history geolocation -n pivori-production

# Rollback à la version précédente
helm rollback geolocation -n pivori-production

# Rollback à une version spécifique
helm rollback geolocation 2 -n pivori-production
```

### Rollback Kubernetes

```bash
# Voir l'historique des déploiements
kubectl rollout history deployment/geolocation -n pivori-production

# Rollback à la version précédente
kubectl rollout undo deployment/geolocation -n pivori-production

# Rollback à une version spécifique
kubectl rollout undo deployment/geolocation --to-revision=2 -n pivori-production
```

### Rollback Backup

```bash
# Restaurer depuis backup
bash scripts/backup/backup-scripts-expert.sh restore_complete /backups/backup.zip

# Vérifier la restauration
bash scripts/backup/backup-scripts-expert.sh verify_backup /backups/backup.zip
```

---

## 📋 CHECKLIST DE DÉPLOIEMENT

### Avant le Déploiement
- [ ] Code testé localement
- [ ] Tests unitaires passés (>90% couverture)
- [ ] Tests d'intégrité réussis
- [ ] Secrets configurés
- [ ] Backups à jour
- [ ] Documentation mise à jour
- [ ] Équipe informée

### Pendant le Déploiement
- [ ] Monitoring actif
- [ ] Logs surveillés
- [ ] Performance mesurée
- [ ] Alertes configurées
- [ ] Équipe disponible

### Après le Déploiement
- [ ] Tous les pods en Running
- [ ] Services accessibles
- [ ] Tests de santé passés
- [ ] Monitoring fonctionnel
- [ ] Backups automatisés
- [ ] Alertes actives
- [ ] Documentation mise à jour

---

## 🚀 COMMANDES RAPIDES

```bash
# Déploiement local
cd services && docker-compose up -d

# Déploiement staging
kubectl apply -f kubernetes/ -n pivori-staging

# Déploiement production
helm install pivori ./helm/pivori -n pivori-production -f values-production.yaml

# Vérifier le statut
kubectl get pods -n pivori-production

# Voir les logs
kubectl logs -f deployment/geolocation -n pivori-production

# Tester les endpoints
curl http://localhost:8010/health

# Rollback
helm rollback geolocation -n pivori-production

# Sauvegarde
bash scripts/backup/backup-scripts-expert.sh backup_complete

# Restauration
bash scripts/backup/backup-scripts-expert.sh restore_complete /backups/backup.zip
```

---

**Guide de Déploiement - Production Ready ✅**


