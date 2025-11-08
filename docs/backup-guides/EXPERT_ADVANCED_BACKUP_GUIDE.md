# 🏆 GUIDE EXPERT AVANCÉ - SAUVEGARDE & RESTAURATION COMPLÈTE

**Niveau:** Expert Qualifié Avancé  
**Date:** 2025-11-08  
**Statut:** Production-Ready  
**Version:** 1.0

---

## 📋 TABLE DES MATIÈRES

1. [Architecture de Sauvegarde](#architecture-de-sauvegarde)
2. [Stratégies d'Optimisation](#stratégies-doptimisation)
3. [Procédures de Sauvegarde](#procédures-de-sauvegarde)
4. [Procédures de Restauration](#procédures-de-restauration)
5. [Vérification d'Intégrité](#vérification-dintégrité)
6. [Plan de Continuité](#plan-de-continuité)
7. [Sécurité & Chiffrement](#sécurité--chiffrement)
8. [Monitoring & Alertes](#monitoring--alertes)

---

## 🏗️ ARCHITECTURE DE SAUVEGARDE

### Composants Principaux

**Rubi Studio** se compose de plusieurs couches:

```
┌─────────────────────────────────────────────────────┐
│                  RUBI STUDIO                         │
├─────────────────────────────────────────────────────┤
│ COUCHE 1: Code Source & Configuration               │
│ ├── services/ (15 services)                          │
│ ├── frontend/                                        │
│ ├── backend/                                         │
│ ├── infrastructure/                                  │
│ └── Documentation/                                   │
├─────────────────────────────────────────────────────┤
│ COUCHE 2: Dépendances & Environnements              │
│ ├── node_modules/ (~500 MB)                          │
│ ├── venv/ (~300-500 MB)                              │
│ └── .git/ (~100-200 MB)                              │
├─────────────────────────────────────────────────────┤
│ COUCHE 3: Données & État                            │
│ ├── PostgreSQL (Database)                            │
│ ├── Redis (Cache)                                    │
│ └── Volumes persistants                              │
├─────────────────────────────────────────────────────┤
│ COUCHE 4: Configuration & Secrets                    │
│ ├── .env files                                       │
│ ├── Kubernetes secrets                               │
│ └── API keys                                         │
└─────────────────────────────────────────────────────┘
```

### Stratégie de Sauvegarde Multi-Niveaux

**Niveau 1: Code & Configuration (Critique)**
- Fréquence: Chaque commit
- Stockage: Git + GitHub
- Taille: ~50 MB
- RTO: 5 minutes
- RPO: 1 minute

**Niveau 2: Dépendances (Important)**
- Fréquence: Hebdomadaire
- Stockage: ZIP complet
- Taille: ~1.2 GB
- RTO: 30 minutes
- RPO: 1 semaine

**Niveau 3: Données (Critique)**
- Fréquence: Quotidienne
- Stockage: PostgreSQL backups
- Taille: Variable
- RTO: 15 minutes
- RPO: 1 heure

**Niveau 4: Secrets (Critique)**
- Fréquence: À chaque changement
- Stockage: Vault/Sealed Secrets
- Taille: <1 MB
- RTO: 5 minutes
- RPO: Immédiat

---

## 🎯 STRATÉGIES D'OPTIMISATION

### Stratégie 1: Sauvegarde Complète (Recommandée)

**Avantages:**
- ✅ Restauration instantanée
- ✅ Pas de dépendances manquantes
- ✅ Environnement identique
- ✅ Pas de recompilation

**Inconvénients:**
- ❌ Très volumineux (~1.5 GB)
- ❌ Temps de création long (~5 min)
- ❌ Stockage coûteux

**Cas d'usage:**
- Backup avant déploiement major
- Snapshot pour disaster recovery
- Archivage long terme

### Stratégie 2: Sauvegarde Intelligente

**Inclure:**
- ✅ Code source
- ✅ Configuration
- ✅ node_modules (cache npm)
- ✅ venv (cache Python)

**Exclure:**
- ❌ .git (peut être cloné)
- ❌ Fichiers temporaires
- ❌ Logs

**Taille:** ~800 MB  
**Temps:** ~2 minutes

### Stratégie 3: Sauvegarde Compressée

**Utiliser:** 7-Zip avec compression maximale

**Compression:**
- ZIP standard: 341 MB → 341 MB (0%)
- 7-Zip niveau 5: 1.5 GB → 600 MB (60%)
- 7-Zip niveau 9: 1.5 GB → 400 MB (73%)

**Temps:** ~5-10 minutes  
**Décompression:** ~2-3 minutes

### Stratégie 4: Sauvegarde Différentielle

**Jour 1:** Sauvegarde complète (1.5 GB)  
**Jour 2:** Sauvegarde différentielle (~100 MB)  
**Jour 3:** Sauvegarde différentielle (~50 MB)  
**Jour 4:** Sauvegarde différentielle (~75 MB)

**Avantages:**
- ✅ Économie de stockage
- ✅ Temps de sauvegarde réduit
- ✅ Bande passante optimisée

**Inconvénients:**
- ❌ Restauration plus complexe
- ❌ Dépendance entre backups

---

## 📦 PROCÉDURES DE SAUVEGARDE

### Procédure 1: Sauvegarde Complète Manuelle

```bash
#!/bin/bash
# backup-complete.sh

set -e  # Arrêter à la première erreur

BACKUP_DIR="/backups"
PROJECT_DIR="/home/ubuntu/rubi-studio"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="rubi-studio-complete-$TIMESTAMP.zip"

echo "🔄 Démarrage sauvegarde complète..."
echo "📁 Répertoire: $PROJECT_DIR"
echo "💾 Destination: $BACKUP_DIR/$BACKUP_FILE"

# Créer le répertoire de backup
mkdir -p "$BACKUP_DIR"

# Vérifier l'espace disque
REQUIRED_SPACE=$((1500 * 1024 * 1024))  # 1.5 GB
AVAILABLE_SPACE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4 * 1024}')

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo "❌ Espace disque insuffisant"
    exit 1
fi

# Créer le ZIP
echo "📦 Création du ZIP..."
cd /home/ubuntu
zip -r -q "$BACKUP_DIR/$BACKUP_FILE" rubi-studio/

# Vérifier l'intégrité
echo "✅ Vérification d'intégrité..."
unzip -t "$BACKUP_DIR/$BACKUP_FILE" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Sauvegarde réussie!"
    ls -lh "$BACKUP_DIR/$BACKUP_FILE"
    
    # Générer checksum
    sha256sum "$BACKUP_DIR/$BACKUP_FILE" > "$BACKUP_DIR/$BACKUP_FILE.sha256"
    echo "📝 Checksum: $(cat $BACKUP_DIR/$BACKUP_FILE.sha256)"
else
    echo "❌ Erreur d'intégrité!"
    rm "$BACKUP_DIR/$BACKUP_FILE"
    exit 1
fi

echo "✅ Sauvegarde complète terminée!"
```

### Procédure 2: Sauvegarde Intelligente

```bash
#!/bin/bash
# backup-smart.sh

BACKUP_DIR="/backups"
PROJECT_DIR="/home/ubuntu/rubi-studio"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="rubi-studio-smart-$TIMESTAMP.zip"

cd /home/ubuntu

# Créer ZIP en excluant .git
zip -r -q "$BACKUP_DIR/$BACKUP_FILE" rubi-studio/ \
    -x "rubi-studio/.git/*" \
    -x "rubi-studio/*/logs/*" \
    -x "rubi-studio/*/.DS_Store"

echo "✅ Sauvegarde intelligente: $BACKUP_FILE"
ls -lh "$BACKUP_DIR/$BACKUP_FILE"
```

### Procédure 3: Sauvegarde Compressée 7-Zip

```bash
#!/bin/bash
# backup-compressed.sh

BACKUP_DIR="/backups"
PROJECT_DIR="/home/ubuntu/rubi-studio"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="rubi-studio-compressed-$TIMESTAMP.7z"

# Installer 7-Zip si nécessaire
if ! command -v 7z &> /dev/null; then
    sudo apt-get install -y p7zip-full
fi

echo "📦 Création archive 7-Zip compressée..."
7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on \
    "$BACKUP_DIR/$BACKUP_FILE" \
    "$PROJECT_DIR"

echo "✅ Sauvegarde compressée: $BACKUP_FILE"
ls -lh "$BACKUP_DIR/$BACKUP_FILE"

# Vérifier l'intégrité
7z t "$BACKUP_DIR/$BACKUP_FILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Intégrité vérifiée"
else
    echo "❌ Erreur d'intégrité"
    exit 1
fi
```

### Procédure 4: Sauvegarde Automatisée (Cron)

```bash
# /etc/cron.d/rubi-studio-backup

# Sauvegarde complète: Dimanche à 2h du matin
0 2 * * 0 ubuntu /home/ubuntu/scripts/backup-complete.sh >> /var/log/rubi-backup.log 2>&1

# Sauvegarde intelligente: Tous les jours à 3h du matin
0 3 * * * ubuntu /home/ubuntu/scripts/backup-smart.sh >> /var/log/rubi-backup.log 2>&1

# Nettoyage des anciens backups: Tous les jours à 4h du matin
0 4 * * * ubuntu find /backups -name "rubi-studio-*" -mtime +30 -delete

# Vérification d'intégrité: Samedi à 1h du matin
0 1 * * 6 ubuntu /home/ubuntu/scripts/verify-backups.sh >> /var/log/rubi-backup.log 2>&1
```

---

## 🔄 PROCÉDURES DE RESTAURATION

### Procédure 1: Restauration Complète

```bash
#!/bin/bash
# restore-complete.sh

BACKUP_FILE="$1"
RESTORE_DIR="/home/ubuntu"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file>"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Fichier non trouvé: $BACKUP_FILE"
    exit 1
fi

echo "🔄 Restauration depuis: $BACKUP_FILE"

# Vérifier l'intégrité avant restauration
echo "✅ Vérification d'intégrité..."
unzip -t "$BACKUP_FILE" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Archive corrompue!"
    exit 1
fi

# Arrêter les services
echo "🛑 Arrêt des services..."
cd "$RESTORE_DIR/rubi-studio"
docker-compose down 2>/dev/null || true

# Backup de l'ancienne version
echo "💾 Backup de l'ancienne version..."
mv "$RESTORE_DIR/rubi-studio" "$RESTORE_DIR/rubi-studio.backup-$(date +%s)"

# Restaurer
echo "📦 Restauration..."
cd "$RESTORE_DIR"
unzip -q "$BACKUP_FILE"

# Restaurer les permissions
echo "🔐 Restauration des permissions..."
chmod -R 755 "$RESTORE_DIR/rubi-studio"

# Réinstaller les dépendances
echo "📚 Réinstallation des dépendances..."
cd "$RESTORE_DIR/rubi-studio/services"
pip install -r requirements.txt 2>/dev/null || true
npm install 2>/dev/null || true

# Redémarrer les services
echo "🚀 Redémarrage des services..."
docker-compose up -d

echo "✅ Restauration complète terminée!"
```

### Procédure 2: Restauration Partielle

```bash
#!/bin/bash
# restore-partial.sh

BACKUP_FILE="$1"
COMPONENTS="$2"  # "services", "frontend", "backend", etc.

# Extraire seulement certains répertoires
unzip -q "$BACKUP_FILE" "rubi-studio/$COMPONENTS/*" -d /tmp/restore

# Copier vers la destination
cp -r /tmp/restore/rubi-studio/$COMPONENTS /home/ubuntu/rubi-studio/

echo "✅ Restauration partielle de: $COMPONENTS"
```

### Procédure 3: Restauration Point-in-Time

```bash
#!/bin/bash
# restore-pit.sh

BACKUP_DATE="$1"  # Format: YYYYMMDD

# Trouver le backup du jour
BACKUP_FILE=$(ls /backups/rubi-studio-complete-$BACKUP_DATE-*.zip | head -1)

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Pas de backup trouvé pour: $BACKUP_DATE"
    exit 1
fi

echo "🔄 Restauration point-in-time: $BACKUP_DATE"
bash /home/ubuntu/scripts/restore-complete.sh "$BACKUP_FILE"
```

---

## ✅ VÉRIFICATION D'INTÉGRITÉ

### Vérification 1: Checksum SHA256

```bash
#!/bin/bash
# verify-checksum.sh

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Fichier non trouvé"
    exit 1
fi

echo "🔍 Vérification checksum..."
sha256sum -c "$BACKUP_FILE.sha256"

if [ $? -eq 0 ]; then
    echo "✅ Checksum valide"
else
    echo "❌ Checksum invalide - Archive corrompue!"
    exit 1
fi
```

### Vérification 2: Intégrité ZIP

```bash
#!/bin/bash
# verify-zip.sh

BACKUP_FILE="$1"

echo "🔍 Vérification intégrité ZIP..."
unzip -t "$BACKUP_FILE" | tail -1

if [ $? -eq 0 ]; then
    echo "✅ Archive intacte"
else
    echo "❌ Archive corrompue"
    exit 1
fi
```

### Vérification 3: Contenu Complet

```bash
#!/bin/bash
# verify-content.sh

BACKUP_FILE="$1"

echo "📋 Vérification du contenu..."

# Vérifier les répertoires critiques
CRITICAL_DIRS=(
    "rubi-studio/services"
    "rubi-studio/backend"
    "rubi-studio/frontend"
    "rubi-studio/infrastructure"
)

for dir in "${CRITICAL_DIRS[@]}"; do
    if unzip -l "$BACKUP_FILE" | grep -q "$dir"; then
        echo "✅ $dir présent"
    else
        echo "❌ $dir manquant"
        exit 1
    fi
done

echo "✅ Contenu complet vérifié"
```

---

## 🏥 PLAN DE CONTINUITÉ

### RTO/RPO Objectives

| Composant | RTO | RPO | Stratégie |
|-----------|-----|-----|-----------|
| Code Source | 5 min | 1 min | Git + GitHub |
| Services | 30 min | 1 heure | Sauvegarde complète |
| Database | 15 min | 1 heure | PostgreSQL backups |
| Secrets | 5 min | Immédiat | Vault |
| Configuration | 10 min | 1 min | Git |

### Scénarios de Récupération

**Scénario 1: Perte d'un service**
1. Restaurer depuis backup
2. Redémarrer le service
3. Vérifier la santé
4. Temps: 5-10 minutes

**Scénario 2: Corruption de données**
1. Identifier le point de corruption
2. Restaurer depuis backup antérieur
3. Rejouer les transactions
4. Temps: 30-60 minutes

**Scénario 3: Perte complète du serveur**
1. Provisionner nouveau serveur
2. Restaurer depuis backup complet
3. Vérifier tous les services
4. Temps: 1-2 heures

**Scénario 4: Compromission de sécurité**
1. Isoler le système
2. Restaurer depuis backup sain
3. Changer tous les secrets
4. Auditer les logs
5. Temps: 2-4 heures

---

## 🔐 SÉCURITÉ & CHIFFREMENT

### Chiffrement GPG

```bash
# Chiffrer un backup
gpg --symmetric --cipher-algo AES256 rubi-studio-complete.zip

# Déchiffrer
gpg --output rubi-studio-complete.zip --decrypt rubi-studio-complete.zip.gpg
```

### Chiffrement 7-Zip

```bash
# Créer archive chiffrée
7z a -t7z -mhe=on -p"YourPassword" rubi-studio.7z rubi-studio/

# Extraire
7z x rubi-studio.7z
```

### Chiffrement avec OpenSSL

```bash
# Chiffrer
openssl enc -aes-256-cbc -salt -in rubi-studio.zip -out rubi-studio.zip.enc

# Déchiffrer
openssl enc -d -aes-256-cbc -in rubi-studio.zip.enc -out rubi-studio.zip
```

### Bonnes Pratiques de Sécurité

- ✅ Chiffrer tous les backups
- ✅ Stocker les mots de passe séparément
- ✅ Utiliser un gestionnaire de secrets
- ✅ Limiter l'accès aux backups
- ✅ Tester la restauration régulièrement
- ✅ Auditer les accès aux backups
- ✅ Supprimer les anciens backups
- ✅ Documenter le processus

---

## 📊 MONITORING & ALERTES

### Métriques à Monitorer

```yaml
# prometheus-backup-rules.yml
groups:
- name: backup_monitoring
  rules:
  - alert: BackupFailed
    expr: backup_status == 0
    for: 5m
    annotations:
      summary: "Sauvegarde échouée"
  
  - alert: BackupTooOld
    expr: (time() - backup_timestamp) > 86400
    annotations:
      summary: "Backup plus ancien que 24h"
  
  - alert: BackupStorageLow
    expr: backup_storage_available < 1000000000  # 1GB
    annotations:
      summary: "Espace de stockage faible"
```

### Alertes Slack

```bash
#!/bin/bash
# send-slack-alert.sh

WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
MESSAGE="$1"
STATUS="$2"

curl -X POST "$WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d "{
    \"text\": \"$MESSAGE\",
    \"attachments\": [{
      \"color\": \"$([ \"$STATUS\" = 'success' ] && echo 'good' || echo 'danger')\",
      \"fields\": [{
        \"title\": \"Timestamp\",
        \"value\": \"$(date)\",
        \"short\": true
      }]
    }]
  }"
```

---

## 📋 CHECKLIST EXPERT

### Avant Sauvegarde
- [ ] Vérifier l'espace disque disponible
- [ ] Arrêter les services non critiques
- [ ] Vérifier la connectivité réseau
- [ ] Documenter la version actuelle
- [ ] Notifier l'équipe

### Pendant Sauvegarde
- [ ] Monitorer la progression
- [ ] Vérifier les logs d'erreurs
- [ ] Vérifier l'utilisation CPU/RAM
- [ ] Vérifier la bande passante

### Après Sauvegarde
- [ ] Vérifier l'intégrité
- [ ] Générer le checksum
- [ ] Tester la restauration
- [ ] Documenter les résultats
- [ ] Archiver les logs
- [ ] Notifier l'équipe

### Maintenance Régulière
- [ ] Tester la restauration mensuellement
- [ ] Vérifier l'intégrité hebdomadairement
- [ ] Nettoyer les anciens backups
- [ ] Mettre à jour la documentation
- [ ] Former l'équipe

---

## 🚀 COMMANDES RAPIDES

```bash
# Sauvegarde complète
bash /home/ubuntu/scripts/backup-complete.sh

# Restauration complète
bash /home/ubuntu/scripts/restore-complete.sh /backups/rubi-studio-complete-*.zip

# Vérifier l'intégrité
bash /home/ubuntu/scripts/verify-checksum.sh /backups/rubi-studio-complete-*.zip

# Lister les backups
ls -lh /backups/rubi-studio-*

# Supprimer les vieux backups (>30 jours)
find /backups -name "rubi-studio-*" -mtime +30 -delete

# Compresser un backup
7z a -t7z -mx=9 rubi-studio.7z /backups/rubi-studio-complete-*.zip

# Chiffrer un backup
gpg --symmetric --cipher-algo AES256 /backups/rubi-studio-complete-*.zip
```

---

## 📞 SUPPORT & ESCALADE

**Pour questions ou problèmes:**
- Email: backup-support@rubi-studio.com
- Slack: #backup-support
- GitHub: rubi-studio/backup/issues

**Responsables:**
- Backup Manager: [Nom]
- Infrastructure Lead: [Nom]
- Security Officer: [Nom]

---

**Document créé:** 2025-11-08  
**Version:** 1.0  
**Statut:** Production-Ready  
**Prochaine révision:** 2025-12-08


