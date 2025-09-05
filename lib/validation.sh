#!/bin/bash
# Funzioni di validazione e verifica - validation.sh

# Carica le dipendenze necessarie
VALIDATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$VALIDATION_DIR/system_utils.sh"

# Funzione per validare nome VM
validate_vm_name() {
    local vm_name="$1"
    
    if [[ ! "$vm_name" =~ ^[a-z][-a-z0-9]{0,62}$ ]]; then
        log_error "Nome VM non valido: $vm_name"
        log_error "Il nome deve iniziare con una lettera minuscola e contenere solo lettere minuscole, numeri e trattini"
        return 1
    fi
    
    log_success "Nome VM valido: $vm_name"
    return 0
}

# Funzione per validare zona GCP
validate_zone() {
    local zone="$1"
    
    if ! gcloud compute zones list --format="value(name)" | grep -q "^${zone}$"; then
        log_error "Zona non valida: $zone"
        return 1
    fi
    
    log_success "Zona valida: $zone"
    return 0
}

# Funzione per verificare se la VM esiste
vm_exists() {
    local vm_name="$1"
    local zone="${2:-$ZONE}"
    
    if gcloud compute instances describe "$vm_name" --zone="$zone" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Funzione per verificare lo stato della VM
check_vm_status() {
    local vm_name="$1"
    local zone="${2:-$ZONE}"
    
    local status=$(gcloud compute instances describe "$vm_name" --zone="$zone" --format="value(status)" 2>/dev/null)
    echo "$status"
}

# Funzione per verificare prerequisiti
check_prerequisites() {
    log_step "Verifica prerequisiti..."
    
    local all_ok=true
    
    # Verifica gcloud
    if ! command_exists gcloud; then
        log_error "gcloud CLI non trovato"
        all_ok=false
    else
        log_success "gcloud CLI presente"
    fi
    
    # Verifica autenticazione gcloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "Nessun account gcloud attivo"
        all_ok=false
    else
        log_success "Account gcloud attivo"
    fi
    
    # Verifica progetto
    if [ -z "$PROJECT_ID" ]; then
        log_error "PROJECT_ID non configurato"
        all_ok=false
    else
        log_success "PROJECT_ID: $PROJECT_ID"
    fi
    
    if [ "$all_ok" = false ]; then
        log_error "Prerequisiti non soddisfatti"
        return 1
    fi
    
    log_success "Tutti i prerequisiti soddisfatti"
    return 0
}

# Funzione per verificare installazione Docker
verify_docker_installation() {
    log_step "Verifica installazione Docker..."
    
    local all_ok=true
    
    # Verifica binario docker
    if ! command_exists docker; then
        log_error "Docker non installato"
        all_ok=false
    else
        log_success "Docker installato: $(docker --version)"
    fi
    
    # Verifica servizio docker
    if ! service_active docker; then
        log_warning "Servizio Docker non attivo"
        all_ok=false
    else
        log_success "Servizio Docker attivo"
    fi
    
    # Verifica docker-compose
    if ! command_exists docker-compose; then
        log_warning "docker-compose non installato"
    else
        log_success "docker-compose installato: $(docker-compose --version)"
    fi
    
    if [ "$all_ok" = false ]; then
        return 1
    fi
    
    return 0
}

# Funzione per verificare configurazione sistema
verify_system_config() {
    log_step "Verifica configurazione sistema..."
    
    # Verifica pacman.conf
    if grep -q "^ParallelDownloads = " /etc/pacman.conf; then
        log_success "ParallelDownloads configurato"
    else
        log_warning "ParallelDownloads non configurato"
    fi
    
    # Verifica D-Bus
    if service_active dbus; then
        log_success "D-Bus classico attivo"
    else
        log_warning "D-Bus classico non attivo"
    fi
    
    if service_enabled dbus-broker; then
        log_warning "dbus-broker ancora abilitato"
    else
        log_success "dbus-broker disabilitato"
    fi
    
    # Verifica gruppi utente
    local current_user=$(whoami)
    local required_groups=("wheel" "docker")
    
    for group in "${required_groups[@]}"; do
        if groups "$current_user" | grep -q "\b$group\b"; then
            log_success "Utente $current_user nel gruppo $group"
        else
            log_warning "Utente $current_user NON nel gruppo $group"
        fi
    done
    
    return 0
}