#!/bin/bash
# Utilities per operazioni di sistema - system_utils.sh

# Funzione per verificare se siamo root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Questo script deve essere eseguito come root"
        exit 1
    fi
}

# Funzione per verificare se NON siamo root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Questo script NON deve essere eseguito come root"
        exit 1
    fi
}

# Funzione per verificare se un comando esiste
command_exists() {
    command -v "$1" &> /dev/null
}

# Funzione per verificare se un pacchetto è installato
package_installed() {
    pacman -Q "$1" &> /dev/null
}

# Funzione per verificare se un servizio è attivo
service_active() {
    systemctl is-active "$1" &> /dev/null
}

# Funzione per verificare se un servizio è abilitato
service_enabled() {
    systemctl is-enabled "$1" &> /dev/null
}

# Funzione per ottenere l'utente corrente (anche se eseguito con sudo)
get_real_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

# Funzione per ottenere la home dell'utente reale
get_real_home() {
    local real_user=$(get_real_user)
    getent passwd "$real_user" | cut -d: -f6
}

# Funzione per verificare la connessione internet
check_internet() {
    log_info "Verifica connessione internet..."
    if ping -c 1 google.com &> /dev/null; then
        log_success "Connessione internet OK"
        return 0
    else
        log_error "Nessuna connessione internet"
        return 1
    fi
}

# Funzione per backup di un file
backup_file() {
    local file="$1"
    local backup="${file}.backup.$(date +%Y%m%d-%H%M%S)"
    
    if [ -f "$file" ]; then
        log_info "Backup di $file in $backup"
        cp "$file" "$backup"
    fi
}

# Funzione per creare directory se non esiste
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log_info "Creazione directory: $dir"
        mkdir -p "$dir"
    fi
}

# Funzione per attendere un processo
wait_for_process() {
    local process="$1"
    local max_wait="${2:-60}"
    local check_interval="${3:-2}"
    
    log_info "Attesa completamento processo: $process (max ${max_wait}s)"
    
    local elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        if ! pgrep -f "$process" > /dev/null; then
            log_success "Processo completato: $process"
            return 0
        fi
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    log_warning "Timeout in attesa del processo: $process"
    return 1
}

# Funzione per verificare spazio su disco
check_disk_space() {
    local min_space_gb="${1:-5}"
    local partition="${2:-/}"
    
    local available_kb=$(df "$partition" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [ $available_gb -lt $min_space_gb ]; then
        log_error "Spazio insufficiente su $partition: ${available_gb}GB disponibili (minimo richiesto: ${min_space_gb}GB)"
        return 1
    else
        log_success "Spazio su disco OK: ${available_gb}GB disponibili su $partition"
        return 0
    fi
}

# Funzione per ottenere informazioni sistema
get_system_info() {
    echo "=== INFORMAZIONI SISTEMA ==="
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "Arch: $(uname -m)"
    echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    echo "RAM: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "Disco: $(df -h / | awk 'NR==2 {print $2}')"
    echo "Utente: $(whoami)"
    echo "Gruppi: $(groups)"
}