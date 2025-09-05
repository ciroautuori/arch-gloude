#!/bin/bash
# Ottimizzazione mirror pacman - 04_mirror_optimization.sh

set -e

# Carica configurazioni e librerie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config/settings.conf"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/system_utils.sh"

print_separator "OTTIMIZZAZIONE MIRROR"

# Verifica di essere root
check_root

log_step "Installazione reflector..."

# Installa reflector se non presente
if ! package_installed reflector; then
    log_info "Installazione reflector..."
    sudo pacman -S reflector --noconfirm
    check_result "Reflector installato" "Errore nell'installazione di reflector"
else
    log_success "Reflector già installato"
fi

log_step "Configurazione mirror italiani/europei..."

# Backup mirrorlist originale
backup_file /etc/pacman.d/mirrorlist

# Configura mirror con parametri precisi
log_info "Ricerca dei mirror più veloci (può richiedere qualche minuto)..."

# Costruisci il comando reflector con i paesi corretti
REFLECTOR_CMD="sudo reflector --verbose --age $MIRROR_AGE --protocol https --sort rate"

# Aggiungi ogni paese come opzione separata
IFS=',' read -ra COUNTRIES <<< "$COUNTRY_MIRRORS"
for country in "${COUNTRIES[@]}"; do
    REFLECTOR_CMD="$REFLECTOR_CMD --country \"$country\""
done

# Esegui il comando
eval "$REFLECTOR_CMD --save /etc/pacman.d/mirrorlist"

check_result "Mirror ottimizzati e salvati" "Errore nell'ottimizzazione dei mirror"

# Verifica mirrorlist
log_info "Verifica mirrorlist..."
if [ -s /etc/pacman.d/mirrorlist ]; then
    mirror_count=$(grep -c "^Server = " /etc/pacman.d/mirrorlist || true)
    log_success "Mirrorlist configurata con $mirror_count mirror"
    
    # Mostra i primi 3 mirror
    log_info "Primi 3 mirror configurati:"
    head -n 10 /etc/pacman.d/mirrorlist | grep "^Server = " | head -n 3
else
    log_error "Mirrorlist vuota o non valida"
    exit 1
fi

# Aggiorna database con nuovi mirror
log_info "Aggiornamento database con nuovi mirror..."
sudo pacman -Syy --noconfirm
check_result "Database aggiornati" "Errore nell'aggiornamento database"

print_separator "OTTIMIZZAZIONE MIRROR COMPLETATA"
