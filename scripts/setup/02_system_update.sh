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

# Prima prova con mirror correnti
if sudo pacman -Syy --noconfirm archlinux-keyring; then
    log_success "Database aggiornati e keyring installato"
else
    log_warning "Problemi con mirror correnti, passo ai mirror ufficiali..."
    
    # Backup mirrorlist corrente
    sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.failed.keyring
    
    # Usa mirror ufficiali per keyring
    cat > /tmp/emergency_keyring_mirrorlist << 'EOF'
##
## Emergency mirrorlist for keyring update
##

# Worldwide CDN (most reliable)
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch

# Official Arch mirrors
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
EOF
    
    sudo cp /tmp/emergency_keyring_mirrorlist /etc/pacman.d/mirrorlist
    
    # Riprova con mirror ufficiali
    if sudo pacman -Syy --noconfirm archlinux-keyring; then
        log_success "Database e keyring aggiornati con mirror ufficiali"
    else
        log_error "Impossibile aggiornare keyring anche con mirror ufficiali"
        exit 1
    fi
fi

# Aggiorna le firme nel keyring
log_info "Aggiornamento firme nel keyring (può richiedere un minuto)..."
sudo pacman-key --refresh-keys
check_result "Firme aggiornate" "Errore nell'aggiornamento delle firme"

log_step "Aggiornamento completo del sistema..."

# Funzione per rilevare errori 404 nell'output pacman
check_404_errors() {
    local log_output="$1"
    local error_count=$(echo "$log_output" | grep -c "404" || echo "0")
    [ "$error_count" -gt 5 ]  # Se più di 5 errori 404, considera i mirror non sincronizzati
}

# Funzione per aggiornamento con retry e rilevamento 404
update_system_with_retry() {
    local max_attempts=3
    local attempt=1
    local temp_log="/tmp/pacman_update.log"
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Tentativo aggiornamento sistema ($attempt/$max_attempts)..."
        
        # Esegui pacman catturando l'output
        if sudo pacman -Syu --noconfirm 2>&1 | tee "$temp_log"; then
            log_success "Sistema aggiornato con successo"
            return 0
        else
            log_warning "Tentativo $attempt fallito"
            
            # Controlla se ci sono molti errori 404
            if [ -f "$temp_log" ] && check_404_errors "$(cat "$temp_log")"; then
                log_warning "Rilevati errori 404 multipli - mirror non sincronizzati"
                return 2  # Codice speciale per errori 404
            fi
            
            if [ $attempt -lt $max_attempts ]; then
                log_info "Attesa 10 secondi prima del prossimo tentativo..."
                sleep 10
                
                # Aggiorna database prima del retry
                sudo pacman -Syy --noconfirm 2>/dev/null || true
            fi
            
            attempt=$((attempt + 1))
        fi
    done
    
    return 1
}

# Aggiorna tutto il sistema con retry intelligente
log_info "Esecuzione aggiornamento sistema (può richiedere alcuni minuti)..."

# Prima prova con mirror configurati
update_result=$(update_system_with_retry; echo $?)

if [ "$update_result" -eq 0 ]; then
    log_success "Aggiornamento completato"
elif [ "$update_result" -eq 2 ]; then
    # Errori 404 rilevati - passa immediatamente ai mirror ufficiali
    log_warning "Errori 404 rilevati - mirror regionali non sincronizzati"
    log_info "Passo immediatamente ai mirror ufficiali..."
    
    # Backup mirrorlist corrente
    sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.404errors
    
    # Configura mirror ufficiali
    cat > /tmp/official_mirrorlist << 'EOF'
##
## Official Arch Linux mirrors (always synchronized)
##

# Worldwide CDN (most reliable)
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch

# Official Tier 1 mirrors
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://archive.archlinux.org/$repo/os/$arch
EOF
    
    sudo cp /tmp/official_mirrorlist /etc/pacman.d/mirrorlist
    
    # Aggiorna database con mirror ufficiali
    log_info "Aggiornamento database con mirror ufficiali..."
    sudo pacman -Syy --noconfirm
    
    # Riprova aggiornamento con mirror ufficiali
    if update_system_with_retry; then
        log_success "Sistema aggiornato con mirror ufficiali"
        log_info "Mirror ufficiali mantenuti per stabilità"
    else
        log_error "Aggiornamento fallito anche con mirror ufficiali"
        exit 1
    fi
else
    # Altri tipi di errore
    log_warning "Aggiornamento fallito, provo con mirror di emergenza..."
    
    # Backup mirrorlist corrente
    sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.failed
    
    # Configura mirror di emergenza
    cat > /tmp/emergency_mirrorlist << 'EOF'
##
## Emergency mirrorlist for system update
##

# Worldwide CDN (most reliable)
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch

# Official mirrors
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
EOF
    
    sudo cp /tmp/emergency_mirrorlist /etc/pacman.d/mirrorlist
    
    # Aggiorna database con mirror di emergenza
    log_info "Aggiornamento database con mirror di emergenza..."
    sudo pacman -Syy --noconfirm
    
    # Riprova aggiornamento
    if update_system_with_retry; then
        log_success "Sistema aggiornato con mirror di emergenza"
        log_info "Mantengo mirror di emergenza per stabilità"
    else
        log_error "Aggiornamento fallito anche con mirror di emergenza"
        
        # Ripristina mirrorlist originale
        if [ -f /etc/pacman.d/mirrorlist.failed ]; then
            sudo mv /etc/pacman.d/mirrorlist.failed /etc/pacman.d/mirrorlist
        fi
        
        log_error "Impossibile aggiornare il sistema"
        exit 1
    fi
fi

# Verifica stato keyring
log_info "Verifica stato keyring..."
if sudo pacman-key --list-keys &>/dev/null; then
    log_success "Keyring funzionante"
else
    log_warning "Possibili problemi con il keyring"
fi

print_separator "AGGIORNAMENTO COMPLETATO"