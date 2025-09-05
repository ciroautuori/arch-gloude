#!/bin/bash
# Setup utente e permessi - 06_user_setup.sh

set -e

# Carica configurazioni e librerie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config/settings.conf"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/system_utils.sh"

print_separator "SETUP UTENTE E PERMESSI"

# Verifica di essere root
check_root

# Ottieni utente reale (anche se eseguito con sudo)
REAL_USER=$(get_real_user)
log_info "Configurazione per utente: $REAL_USER"

log_step "Aggiunta utente ai gruppi necessari..."

# Gruppi da aggiungere
GROUPS_TO_ADD="wheel,docker,storage,power,network,disk,sys"

# Aggiungi utente ai gruppi
log_info "Aggiunta di $REAL_USER ai gruppi: $GROUPS_TO_ADD"
sudo usermod -aG $GROUPS_TO_ADD $REAL_USER
check_result "Utente aggiunto ai gruppi" "Errore nell'aggiunta ai gruppi"

# Verifica gruppi
log_info "Verifica gruppi utente..."
user_groups=$(groups $REAL_USER)
log_success "Gruppi attuali di $REAL_USER: $user_groups"

log_step "Abilitazione servizio Docker..."

# Abilita Docker (NON avviarlo ora, verrà avviato dopo il riavvio)
log_info "Abilitazione docker.service per l'avvio automatico..."
sudo systemctl enable docker.service
check_result "Docker abilitato all'avvio" "Errore nell'abilitazione di Docker"

# NON avviare Docker ora perché:
# 1. D-Bus non è ancora configurato correttamente
# 2. I gruppi utente non sono ancora attivi (serve riavvio/riconnessione)
log_info "Docker verrà avviato automaticamente dopo il riavvio del sistema"

# Verifica solo che sia abilitato
if service_enabled docker; then
    log_success "Docker configurato per l'avvio automatico"
else
    log_warning "Docker potrebbe non essere configurato correttamente"
fi

# Crea directory docker projects per l'utente
REAL_HOME=$(get_real_home)
DOCKER_DIR="$REAL_HOME/docker-projects"

if [ ! -d "$DOCKER_DIR" ]; then
    log_info "Creazione directory $DOCKER_DIR..."
    sudo -u $REAL_USER mkdir -p "$DOCKER_DIR"
    log_success "Directory docker-projects creata"
else
    log_info "Directory docker-projects già esistente"
fi

# Imposta permessi corretti
sudo chown -R $REAL_USER:$REAL_USER "$DOCKER_DIR"
log_success "Permessi directory configurati"

log_warning "NOTA: L'utente dovrà fare logout/login per applicare i nuovi gruppi"
log_info "In alternativa, eseguire: newgrp docker"

print_separator "SETUP UTENTE COMPLETATO"
