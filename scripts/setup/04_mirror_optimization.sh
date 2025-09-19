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

# Verifica dipendenze necessarie
if ! command_exists curl; then
    log_info "Installazione curl per test mirror..."
    # Usa mirror di emergenza per installare curl se necessario
    if ! sudo pacman -S curl --noconfirm; then
        log_warning "Impossibile installare curl, salto test mirror"
        SKIP_MIRROR_TEST=true
    fi
else
    SKIP_MIRROR_TEST=false
fi

# Funzione per testare un mirror
test_mirror() {
    local mirror_url="$1"
    log_info "Test mirror: $mirror_url"
    
    # Test connessione al mirror
    if curl -s --connect-timeout 5 --max-time 10 "$mirror_url/core/os/x86_64/core.db" > /dev/null 2>&1; then
        log_success "Mirror funzionante: $mirror_url"
        return 0
    else
        log_warning "Mirror non raggiungibile: $mirror_url"
        return 1
    fi
}

# Funzione per configurare mirror di emergenza
setup_emergency_mirrors() {
    log_warning "Configurazione mirror di emergenza..."
    
    # Mirror ufficiali sempre funzionanti
    cat > /etc/pacman.d/mirrorlist << 'EOF'
##
## Arch Linux repository mirrorlist - Emergency fallback
##

# Worldwide CDN (usually most reliable)
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch

# Official Arch Linux mirrors
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://archive.archlinux.org/$repo/os/$arch
EOF
    
    log_success "Mirror di emergenza configurati"
}

log_step "Installazione reflector..."

# Prima configura mirror di emergenza per installare reflector
if ! package_installed reflector; then
    log_info "Configurazione mirror temporanei per installare reflector..."
    setup_emergency_mirrors
    
    # Aggiorna database con mirror di emergenza
    sudo pacman -Syy --noconfirm
    
    log_info "Installazione reflector..."
    if sudo pacman -S reflector --noconfirm; then
        log_success "Reflector installato"
    else
        log_error "Impossibile installare reflector"
        exit 1
    fi
else
    log_success "Reflector già installato"
fi

log_step "Configurazione mirror ottimizzati..."

# Backup mirrorlist originale
backup_file /etc/pacman.d/mirrorlist

# Strategia a più livelli per la configurazione mirror
MIRROR_CONFIGURED=false

# Livello 1: Mirror regionali ottimizzati
if [ "$MIRROR_CONFIGURED" = false ]; then
    log_info "Tentativo 1: Mirror regionali (${COUNTRY_MIRRORS})..."
    
    if sudo reflector \
        --verbose \
        --age $MIRROR_AGE \
        --protocol https \
        --country "$COUNTRY_MIRRORS" \
        --sort rate \
        --number 10 \
        --save /etc/pacman.d/mirrorlist 2>/dev/null; then
        
        # Verifica che la mirrorlist non sia vuota
        if [ -s /etc/pacman.d/mirrorlist ] && grep -q "^Server = " /etc/pacman.d/mirrorlist; then
            log_success "Mirror regionali configurati"
            MIRROR_CONFIGURED=true
        else
            log_warning "Mirrorlist vuota, provo livello successivo"
        fi
    else
        log_warning "Reflector fallito per mirror regionali"
    fi
fi

# Livello 2: Mirror europei + USA
if [ "$MIRROR_CONFIGURED" = false ]; then
    log_info "Tentativo 2: Mirror europei e USA..."
    
    if sudo reflector \
        --verbose \
        --age 6 \
        --protocol https \
        --country "Germany,France,Netherlands,United States" \
        --sort rate \
        --number 8 \
        --save /etc/pacman.d/mirrorlist 2>/dev/null; then
        
        if [ -s /etc/pacman.d/mirrorlist ] && grep -q "^Server = " /etc/pacman.d/mirrorlist; then
            log_success "Mirror europei/USA configurati"
            MIRROR_CONFIGURED=true
        fi
    fi
fi

# Livello 3: Mirror globali più veloci
if [ "$MIRROR_CONFIGURED" = false ]; then
    log_info "Tentativo 3: Mirror globali più veloci..."
    
    if sudo reflector \
        --verbose \
        --age 12 \
        --protocol https \
        --sort rate \
        --number 5 \
        --save /etc/pacman.d/mirrorlist 2>/dev/null; then
        
        if [ -s /etc/pacman.d/mirrorlist ] && grep -q "^Server = " /etc/pacman.d/mirrorlist; then
            log_success "Mirror globali configurati"
            MIRROR_CONFIGURED=true
        fi
    fi
fi

# Livello 4: Mirror di emergenza
if [ "$MIRROR_CONFIGURED" = false ]; then
    log_warning "Tutti i tentativi reflector falliti, uso mirror di emergenza"
    setup_emergency_mirrors
    MIRROR_CONFIGURED=true
fi

# Verifica finale mirrorlist
log_info "Verifica configurazione mirror..."
if [ -s /etc/pacman.d/mirrorlist ]; then
    mirror_count=$(grep -c "^Server = " /etc/pacman.d/mirrorlist || echo "0")
    if [ "$mirror_count" -gt 0 ]; then
        log_success "Mirrorlist configurata con $mirror_count mirror"
        
        # Mostra i primi 3 mirror
        log_info "Mirror configurati:"
        grep "^Server = " /etc/pacman.d/mirrorlist | head -n 3 | while read -r line; do
            echo "  $line"
        done
    else
        log_error "Nessun mirror valido trovato"
        exit 1
    fi
else
    log_error "Mirrorlist vuota"
    exit 1
fi

# Test connettività primo mirror
if [ "$SKIP_MIRROR_TEST" = false ]; then
    FIRST_MIRROR=$(grep "^Server = " /etc/pacman.d/mirrorlist | head -n 1 | sed 's/Server = //' | sed 's/\$repo\/os\/\$arch//')
    if [ -n "$FIRST_MIRROR" ]; then
        test_mirror "$FIRST_MIRROR" || log_warning "Primo mirror potrebbe avere problemi"
    fi
else
    log_info "Test mirror saltato (curl non disponibile)"
fi

# Test sincronizzazione mirror configurati
log_info "Test sincronizzazione mirror..."
temp_test_log="/tmp/mirror_sync_test.log"

if sudo pacman -Sy --noconfirm 2>&1 | tee "$temp_test_log"; then
    log_success "Database aggiornati con successo"
    
    # Controlla se ci sono errori 404 nel test
    if [ -f "$temp_test_log" ]; then
        error_404_count=$(grep -c "404" "$temp_test_log" 2>/dev/null || echo "0")
        if [ "$error_404_count" -gt 3 ]; then
            log_warning "Rilevati $error_404_count errori 404 - mirror non sincronizzati"
            log_info "Passo automaticamente ai mirror ufficiali..."
            
            # Backup mirrorlist problematica
            sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.sync_issues
            
            # Usa mirror ufficiali
            setup_emergency_mirrors
            
            # Riprova aggiornamento database
            if sudo pacman -Syy --noconfirm; then
                log_success "Database aggiornati con mirror ufficiali"
            else
                log_warning "Problemi anche con mirror ufficiali"
            fi
        else
            log_success "Mirror sincronizzati correttamente"
        fi
    fi
else
    log_warning "Problemi nell'aggiornamento database"
    
    # Se fallisce completamente, usa mirror ufficiali
    log_info "Fallback automatico ai mirror ufficiali..."
    setup_emergency_mirrors
    
    if sudo pacman -Syy --noconfirm; then
        log_success "Database aggiornati con mirror ufficiali"
    else
        log_error "Impossibile aggiornare database anche con mirror ufficiali"
        exit 1
    fi
fi

print_separator "OTTIMIZZAZIONE MIRROR COMPLETATA"
