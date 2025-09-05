#!/bin/bash
# Aggiornamento sistema e keyring - 02_system_update.sh

set -e

# Carica configurazioni e librerie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config/settings.conf"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/system_utils.sh"

print_separator "AGGIORNAMENTO SISTEMA E KEYRING"

# Verifica di essere root
check_root

log_step "Aggiornamento chiavi PGP..."

# Eliminazione gnupg se corrotto
if [ -d /etc/pacman.d/gnupg ]; then
    log_info "Rimozione directory gnupg esistente..."
    sudo rm -rf /etc/pacman.d/gnupg
    log_success "Directory gnupg rimossa"
fi

# Inizializza il portachiavi di Pacman
log_info "Inizializzazione portachiavi pacman..."
sudo pacman-key --init
check_result "Portachiavi inizializzato" "Errore nell'inizializzazione del portachiavi"

# Popola il portachiavi con le chiavi di Arch Linux
log_info "Popolazione portachiavi con chiavi Arch Linux..."
sudo pacman-key --populate archlinux
check_result "Portachiavi popolato" "Errore nel popolare il portachiavi"

# Forza il refresh dei database dei pacchetti
log_info "Refresh forzato dei database pacchetti..."
sudo pacman -Syy --noconfirm archlinux-keyring
check_result "Database aggiornati e keyring installato" "Errore nell'aggiornamento database"

# Aggiorna le firme nel keyring
log_info "Aggiornamento firme nel keyring (può richiedere un minuto)..."
sudo pacman-key --refresh-keys
check_result "Firme aggiornate" "Errore nell'aggiornamento delle firme"

log_step "Aggiornamento completo del sistema..."

# Aggiorna tutto il sistema
log_info "Esecuzione aggiornamento sistema (può richiedere alcuni minuti)..."
sudo pacman -Syu --noconfirm
check_result "Sistema aggiornato con successo" "Errore nell'aggiornamento del sistema"

# Verifica stato keyring
log_info "Verifica stato keyring..."
if sudo pacman-key --list-keys &>/dev/null; then
    log_success "Keyring funzionante"
else
    log_warning "Possibili problemi con il keyring"
fi

print_separator "AGGIORNAMENTO COMPLETATO"