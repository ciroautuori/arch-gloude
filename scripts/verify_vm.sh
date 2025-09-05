#!/bin/bash
# Script di verifica post-riavvio - verify_vm.sh

set -e

# Trova la directory radice del progetto (dove si trova main.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Carica configurazioni e librerie con path assoluti
source "$PROJECT_ROOT/config/settings.conf"
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/validation.sh"
source "$PROJECT_ROOT/lib/system_utils.sh"

# Inizializza log
initialize_log

print_separator "VERIFICA POST-RIAVVIO"

log_step "Verifica connessione e sistema..."

# Informazioni base
log_info "=== VERIFICA SISTEMA ==="
echo "User: $(whoami)"
echo "Groups: $(groups)"
echo "Hostname: $(hostname)"
echo "Directory corrente: $(pwd)"

# Verifica Docker
log_step "Verifica Docker..."

if command_exists docker; then
    echo "Docker version: $(docker --version)"
    
    # Verifica servizio Docker
    if service_active docker; then
        log_success "Docker status: attivo"
        
        # Prova ad eseguire docker senza sudo
        if docker ps &>/dev/null; then
            log_success "Docker funziona senza sudo"
        else
            log_warning "Docker richiede sudo o logout/login per applicare i gruppi"
            log_info "Prova: newgrp docker"
        fi
    else
        log_warning "Docker non attivo"
        log_info "Avvio Docker..."
        sudo systemctl start docker.service
        
        if service_active docker; then
            log_success "Docker avviato con successo"
        else
            log_error "Impossibile avviare Docker"
        fi
    fi
else
    log_error "Docker non installato"
fi

# Verifica Docker Compose
if command_exists docker-compose; then
    echo "Docker Compose: $(docker-compose --version)"
else
    log_warning "Docker Compose non trovato"
fi

# Verifica D-Bus
log_step "Verifica D-Bus..."

if service_active dbus; then
    log_success "D-Bus status: attivo (classico)"
else
    log_error "D-Bus non attivo"
fi

if service_enabled dbus-broker; then
    log_warning "dbus-broker ancora abilitato (dovrebbe essere disabilitato)"
else
    log_success "dbus-broker correttamente disabilitato"
fi

# Verifica Starship
log_step "Verifica Starship..."

if command_exists starship; then
    log_success "Starship installato: $(which starship)"
else
    log_warning "Starship non trovato"
fi

# Verifica directory progetti
log_step "Verifica directory progetti..."

if [ -d "$DOCKER_PROJECTS_DIR" ]; then
    log_success "Directory docker-projects presente: $DOCKER_PROJECTS_DIR"
    cd "$DOCKER_PROJECTS_DIR"
    log_info "Spostato in: $(pwd)"
else
    log_info "Creazione directory docker-projects..."
    mkdir -p "$DOCKER_PROJECTS_DIR"
    cd "$DOCKER_PROJECTS_DIR"
    log_success "Directory creata e posizionato in: $(pwd)"
fi

# Test Docker con hello-world
log_step "Test Docker con container hello-world..."

if docker --version &>/dev/null; then
    log_info "Esecuzione test container..."
    if docker run --rm hello-world &>/dev/null; then
        log_success "Docker funziona correttamente!"
    else
        log_warning "Test Docker fallito - potrebbe essere necessario sudo o newgrp docker"
    fi
else
    log_warning "Docker non disponibile per il test"
fi

# Riepilogo finale
print_separator "RIEPILOGO VERIFICA"

echo ""
echo "=== STATO SISTEMA ==="
echo "✓ Sistema operativo: Arch Linux"
echo "✓ Utente: $(whoami)"
echo "✓ Gruppi: $(groups)"
echo ""
echo "=== STATO SERVIZI ==="
echo "$(service_active docker && echo '✓' || echo '✗') Docker: $(service_active docker && echo 'Attivo' || echo 'Non attivo')"
echo "$(service_active dbus && echo '✓' || echo '✗') D-Bus: $(service_active dbus && echo 'Attivo' || echo 'Non attivo')"
echo ""
echo "=== SOFTWARE INSTALLATO ==="
echo "$(command_exists docker && echo '✓' || echo '✗') Docker"
echo "$(command_exists docker-compose && echo '✓' || echo '✗') Docker Compose"
echo "$(command_exists git && echo '✓' || echo '✗') Git"
echo "$(command_exists starship && echo '✓' || echo '✗') Starship"
echo ""

# Suggerimenti finali
if ! docker ps &>/dev/null 2>&1; then
    echo "=== AZIONI CONSIGLIATE ==="
    echo "Se Docker richiede sudo, esegui uno dei seguenti:"
    echo "  1. Logout e login per applicare i gruppi"
    echo "  2. Esegui: newgrp docker"
    echo ""
fi

log_success "Verifica completata!"

print_separator "FINE VERIFICA"