#!/bin/bash
# Gestione riavvio e cleanup - 08_system_restart.sh

set -e

# Carica configurazioni e librerie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config/settings.conf"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/system_utils.sh"

print_separator "RIAVVIO SISTEMA"

log_step "Preparazione per il riavvio..."

# Pulizia cache pacman (silente)
sudo pacman -Sc --noconfirm >/dev/null 2>&1

# Salva informazioni di sistema
log_info "Salvataggio informazioni sistema..."
get_system_info > /tmp/system_info_pre_restart.txt
log_success "Informazioni salvate in /tmp/system_info_pre_restart.txt"

# Verifica servizi critici prima del riavvio
log_info "Verifica servizi critici..."
if service_enabled docker; then
    log_success "Docker configurato per avvio automatico"
else
    log_warning "Docker non configurato per avvio automatico"
fi

if service_enabled dbus; then
    log_success "D-Bus configurato per avvio automatico"
else
    log_warning "D-Bus non configurato per avvio automatico"
fi

log_step "Preparazione per riavvio..."

# In modalità automatica, prepara solo per il riavvio senza menu interattivo
log_info "La VM è pronta per il riavvio per applicare tutte le modifiche."
log_info "Il riavvio verrà gestito automaticamente dall'orchestratore."

echo ""
echo "Info post-riavvio:"
echo "  - I gruppi utente saranno attivati"
echo "  - Docker sarà disponibile senza sudo"
echo "  - D-Bus sarà completamente funzionante"
echo ""

print_separator "PROCEDURA COMPLETATA"
