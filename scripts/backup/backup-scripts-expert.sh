#!/bin/bash
# ============================================================================
# RUBI STUDIO - EXPERT BACKUP & RESTORE SCRIPTS
# ============================================================================
# Niveau: Expert Qualifié Avancé
# Version: 1.0
# Date: 2025-11-08
# ============================================================================

set -e  # Arrêter à la première erreur

# Configuration
BACKUP_DIR="/backups"
PROJECT_DIR="/home/ubuntu/rubi-studio"
LOG_DIR="/var/log/rubi-backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/backup-$TIMESTAMP.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

check_space() {
    local required=$1
    local available=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4 * 1024}')
    
    if [ "$available" -lt "$required" ]; then
        error "Espace disque insuffisant. Requis: $((required / 1024 / 1024))MB, Disponible: $((available / 1024 / 1024))MB"
        return 1
    fi
    return 0
}

verify_integrity() {
    local backup_file=$1
    
    log "Vérification d'intégrité..."
    if unzip -t "$backup_file" > /dev/null 2>&1; then
        success "Intégrité vérifiée"
        return 0
    else
        error "Archive corrompue"
        return 1
    fi
}

generate_checksum() {
    local backup_file=$1
    
    log "Génération du checksum..."
    sha256sum "$backup_file" > "$backup_file.sha256"
    success "Checksum généré: $(cat $backup_file.sha256 | awk '{print $1}')"
}

# ============================================================================
# SAUVEGARDE COMPLÈTE
# ============================================================================

backup_complete() {
    log "🔄 Démarrage sauvegarde COMPLÈTE..."
    log "📁 Répertoire: $PROJECT_DIR"
    
    # Créer le répertoire de backup
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    
    # Vérifier l'espace disque (1.5 GB requis)
    check_space $((1500 * 1024 * 1024)) || return 1
    
    # Créer le ZIP
    local backup_file="$BACKUP_DIR/rubi-studio-complete-$TIMESTAMP.zip"
    log "📦 Création du ZIP (cela peut prendre 3-5 minutes)..."
    
    cd /home/ubuntu
    zip -r -q "$backup_file" rubi-studio/ 2>&1 | tee -a "$LOG_FILE"
    
    # Vérifier l'intégrité
    verify_integrity "$backup_file" || return 1
    
    # Générer le checksum
    generate_checksum "$backup_file"
    
    # Afficher les informations
    success "Sauvegarde complète terminée!"
    log "Fichier: $(basename $backup_file)"
    log "Taille: $(du -h $backup_file | cut -f1)"
    log "Checksum: $(cat $backup_file.sha256 | awk '{print $1}')"
}

# ============================================================================
# SAUVEGARDE INTELLIGENTE
# ============================================================================

backup_smart() {
    log "🔄 Démarrage sauvegarde INTELLIGENTE..."
    
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    check_space $((800 * 1024 * 1024)) || return 1
    
    local backup_file="$BACKUP_DIR/rubi-studio-smart-$TIMESTAMP.zip"
    log "📦 Création du ZIP (exclusion de .git)..."
    
    cd /home/ubuntu
    zip -r -q "$backup_file" rubi-studio/ \
        -x "rubi-studio/.git/*" \
        -x "rubi-studio/*/logs/*" \
        -x "rubi-studio/*/.DS_Store" 2>&1 | tee -a "$LOG_FILE"
    
    verify_integrity "$backup_file" || return 1
    generate_checksum "$backup_file"
    
    success "Sauvegarde intelligente terminée!"
    log "Fichier: $(basename $backup_file)"
    log "Taille: $(du -h $backup_file | cut -f1)"
}

# ============================================================================
# SAUVEGARDE COMPRESSÉE 7-ZIP
# ============================================================================

backup_compressed() {
    log "🔄 Démarrage sauvegarde COMPRESSÉE..."
    
    # Vérifier 7-Zip
    if ! command -v 7z &> /dev/null; then
        log "Installation de 7-Zip..."
        sudo apt-get install -y p7zip-full > /dev/null 2>&1
    fi
    
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    check_space $((500 * 1024 * 1024)) || return 1
    
    local backup_file="$BACKUP_DIR/rubi-studio-compressed-$TIMESTAMP.7z"
    log "📦 Création archive 7-Zip (compression maximale)..."
    
    7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on \
        "$backup_file" "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE"
    
    # Vérifier l'intégrité
    if 7z t "$backup_file" > /dev/null 2>&1; then
        success "Intégrité vérifiée"
    else
        error "Archive corrompue"
        return 1
    fi
    
    generate_checksum "$backup_file"
    
    success "Sauvegarde compressée terminée!"
    log "Fichier: $(basename $backup_file)"
    log "Taille: $(du -h $backup_file | cut -f1)"
}

# ============================================================================
# RESTAURATION COMPLÈTE
# ============================================================================

restore_complete() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        error "Usage: restore_complete <backup-file>"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        error "Fichier non trouvé: $backup_file"
        return 1
    fi
    
    log "🔄 Restauration depuis: $(basename $backup_file)"
    
    # Vérifier l'intégrité
    log "✅ Vérification d'intégrité..."
    verify_integrity "$backup_file" || return 1
    
    # Arrêter les services
    log "🛑 Arrêt des services..."
    cd "$PROJECT_DIR" 2>/dev/null && docker-compose down 2>/dev/null || true
    
    # Backup de l'ancienne version
    log "💾 Backup de l'ancienne version..."
    if [ -d "$PROJECT_DIR" ]; then
        mv "$PROJECT_DIR" "$PROJECT_DIR.backup-$(date +%s)"
    fi
    
    # Restaurer
    log "📦 Restauration..."
    cd /home/ubuntu
    unzip -q "$backup_file"
    
    # Restaurer les permissions
    log "🔐 Restauration des permissions..."
    chmod -R 755 "$PROJECT_DIR"
    
    # Réinstaller les dépendances
    log "📚 Réinstallation des dépendances..."
    cd "$PROJECT_DIR/services"
    pip install -r requirements.txt 2>/dev/null || true
    npm install 2>/dev/null || true
    
    # Redémarrer les services
    log "🚀 Redémarrage des services..."
    docker-compose up -d 2>/dev/null || true
    
    success "Restauration complète terminée!"
}

# ============================================================================
# VÉRIFICATION D'INTÉGRITÉ
# ============================================================================

verify_backup() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        error "Usage: verify_backup <backup-file>"
        return 1
    fi
    
    log "🔍 Vérification du backup: $(basename $backup_file)"
    
    # Vérifier le fichier
    if [ ! -f "$backup_file" ]; then
        error "Fichier non trouvé"
        return 1
    fi
    
    # Vérifier le checksum
    if [ -f "$backup_file.sha256" ]; then
        log "Vérification du checksum..."
        sha256sum -c "$backup_file.sha256" | tee -a "$LOG_FILE"
    fi
    
    # Vérifier l'intégrité
    verify_integrity "$backup_file" || return 1
    
    # Afficher les statistiques
    log "Statistiques:"
    log "  Taille: $(du -h $backup_file | cut -f1)"
    log "  Fichiers: $(unzip -l $backup_file | tail -1 | awk '{print $2}')"
    log "  Date: $(stat -f %Sm -t '%Y-%m-%d %H:%M:%S' $backup_file 2>/dev/null || stat -c %y $backup_file)"
    
    success "Vérification complète"
}

# ============================================================================
# NETTOYAGE DES ANCIENS BACKUPS
# ============================================================================

cleanup_old_backups() {
    local days=${1:-30}
    
    log "🧹 Nettoyage des backups plus anciens que $days jours..."
    
    find "$BACKUP_DIR" -name "rubi-studio-*" -mtime +$days -type f | while read file; do
        log "Suppression: $(basename $file)"
        rm "$file" "$file.sha256" 2>/dev/null || true
    done
    
    success "Nettoyage terminé"
}

# ============================================================================
# MENU PRINCIPAL
# ============================================================================

show_menu() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     RUBI STUDIO - EXPERT BACKUP & RESTORE TOOLS            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "SAUVEGARDE:"
    echo "  1) Sauvegarde COMPLÈTE (1.5 GB, 3-5 min)"
    echo "  2) Sauvegarde INTELLIGENTE (800 MB, 2 min)"
    echo "  3) Sauvegarde COMPRESSÉE 7-ZIP (400 MB, 5-10 min)"
    echo ""
    echo "RESTAURATION:"
    echo "  4) Restauration COMPLÈTE"
    echo "  5) Lister les backups"
    echo ""
    echo "MAINTENANCE:"
    echo "  6) Vérifier l'intégrité d'un backup"
    echo "  7) Nettoyer les anciens backups"
    echo "  8) Afficher les logs"
    echo ""
    echo "  0) Quitter"
    echo ""
}

main() {
    while true; do
        show_menu
        read -p "Sélectionnez une option: " choice
        
        case $choice in
            1) backup_complete ;;
            2) backup_smart ;;
            3) backup_compressed ;;
            4) 
                read -p "Chemin du backup: " backup_file
                restore_complete "$backup_file"
                ;;
            5) ls -lh "$BACKUP_DIR"/rubi-studio-* 2>/dev/null || echo "Aucun backup trouvé" ;;
            6)
                read -p "Chemin du backup: " backup_file
                verify_backup "$backup_file"
                ;;
            7) cleanup_old_backups ;;
            8) tail -50 "$LOG_FILE" ;;
            0) exit 0 ;;
            *) error "Option invalide" ;;
        esac
    done
}

# Exécuter le menu si aucun argument
if [ $# -eq 0 ]; then
    main
else
    # Exécuter la commande passée en argument
    "$@"
fi

