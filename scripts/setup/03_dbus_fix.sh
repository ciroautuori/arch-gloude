#!/bin/bash
# Fix D-Bus e servizi core - 03_dbus_fix.sh

set -e

# Carica configurazioni e librerie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config/settings.conf"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/system_utils.sh"

print_separator "FIX D-BUS E SERVIZI CORE"

# Verifica di essere root
check_root

log_step "Risoluzione problema D-Bus..."

# Ferma dbus-broker se attivo
if service_active dbus-broker; then
    log_info "Arresto dbus-broker.service..."
    sudo systemctl stop dbus-broker.service
    log_success "dbus-broker fermato"
else
    log_info "dbus-broker non attivo"
fi

# Disabilita dbus-broker (causa timeout nei container)
if service_enabled dbus-broker; then
    log_info "Disabilitazione dbus-broker.service..."
    sudo systemctl disable dbus-broker.service
    log_success "dbus-broker disabilitato"
else
    log_info "dbus-broker già disabilitato"
fi

# Abilita dbus classico (più stabile)
log_info "Abilitazione dbus.service classico..."
sudo systemctl enable dbus.service
check_result "dbus.service abilitato" "Errore nell'abilitazione di dbus.service"

# Avvia dbus classico
log_info "Avvio dbus.service..."
sudo systemctl start dbus.service
check_result "dbus.service avviato" "Errore nell'avvio di dbus.service"

# Verifica stato D-Bus
log_info "Verifica stato D-Bus..."
if service_active dbus; then
    log_success "D-Bus classico attivo e funzionante"
else
    log_error "D-Bus classico non attivo"
    exit 1
fi

# Verifica che dbus-broker sia effettivamente disabilitato
if ! service_enabled dbus-broker; then
    log_success "dbus-broker correttamente disabilitato"
else
    log_warning "dbus-broker ancora abilitato"
fi

print_separator "FIX D-BUS COMPLETATO"
