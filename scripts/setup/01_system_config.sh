#!/bin/bash
# Configurazione sistema base - 01_system_config.sh

set -e

# Carica configurazioni e librerie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config/settings.conf"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/system_utils.sh"

print_separator "CONFIGURAZIONE SISTEMA BASE"

# Verifica di essere root
check_root

log_step "Configurazione pacman.conf..."

# Backup del file originale
backup_file /etc/pacman.conf

# Abilita colori
sudo sed -i '/^#Color/c\Color' /etc/pacman.conf
log_success "Colori abilitati"

# Abilita VerbosePkgLists
sudo sed -i '/^#VerbosePkgLists/c\VerbosePkgLists' /etc/pacman.conf
log_success "VerbosePkgLists abilitato"

# Abilita download paralleli
sudo sed -i '/^#ParallelDownloads/c\ParallelDownloads = 5' /etc/pacman.conf
log_success "Download paralleli configurati: 5"

# Aggiungi ILoveCandy (progress bar pacman)
if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
    sudo sed -i '/^ParallelDownloads = 5/a ILoveCandy' /etc/pacman.conf
    log_success "ILoveCandy aggiunto"
fi

# Rimuovi repository community (deprecato)
sudo sed -i '/^\[community\]/,/^$/d' /etc/pacman.conf
log_success "Repository community rimosso"

log_step "Configurazione sudoers..."

# Configura wheel group per sudo senza password
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/wheel-nopasswd > /dev/null
log_success "Gruppo wheel configurato per sudo senza password"

# Verifica configurazione
log_info "Verifica configurazione pacman..."
if grep -q "^ParallelDownloads = 5" /etc/pacman.conf && \
   grep -q "^Color" /etc/pacman.conf && \
   grep -q "^VerbosePkgLists" /etc/pacman.conf; then
    log_success "Configurazione pacman verificata"
else
    log_warning "Alcune configurazioni pacman potrebbero non essere state applicate"
fi

print_separator "CONFIGURAZIONE SISTEMA COMPLETATA"