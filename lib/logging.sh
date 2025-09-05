#!/bin/bash
# Sistema di logging avanzato - logging.sh

# Importa colori se non già definiti
if [ -z "$RED" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
fi

# File di log
LOG_FILE="${LOG_FILE:-/tmp/arch-setup-$(date +%Y%m%d-%H%M%S).log}"

# Funzione di logging principale
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log su file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Output su console con colori
    case "$level" in
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        DEBUG)
            if [ "${DEBUG:-0}" = "1" ]; then
                echo -e "${CYAN}[DEBUG]${NC} $message"
            fi
            ;;
        STEP)
            echo -e "${MAGENTA}[STEP]${NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Logging avanzato con timestamp e persistenza
log_with_timestamp() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Scrivi su file se LOG_FILE è definito e scrivibile
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Funzioni wrapper enterprise con timestamp
log_error() { 
    local msg="$1"
    echo -e "${RED}[❌ ERROR]${NC} $msg"
    log_with_timestamp "ERROR" "$msg"
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

log_warning() { 
    local msg="$1"
    echo -e "${YELLOW}[⚠️ WARNING]${NC} $msg"
    log_with_timestamp "WARNING" "$msg"
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

log_success() {
    local msg="$1"
    echo -e "${GREEN}✓ $msg${NC}"
    log_with_timestamp "SUCCESS" "$msg"
}

log_info() { 
    local msg="$1"
    echo -e "${BLUE}[INFO]${NC} $msg"
    log_with_timestamp "INFO" "$msg"
}

log_debug() { 
    local msg="$1"
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $msg"
        log_with_timestamp "DEBUG" "$msg"
    fi
}

log_step() { 
    local msg="$1"
    echo -e "${CYAN}[STEP]${NC} $msg"
    log_with_timestamp "STEP" "$msg"
}

# Funzione per calcolare il padding per centrare il testo
calculate_padding() {
    local str="$1"
    local width=$2
    local str_length=${#str}
    
    # Calcola il padding totale necessario
    local total_padding=$((width - str_length))
    
    # Se la stringa è più lunga della larghezza, ritorna 0
    [ $total_padding -lt 0 ] && { echo "0 0"; return; }
    
    # Calcola padding sinistro e destro
    local left_padding=$((total_padding / 2))
    local right_padding=$((total_padding - left_padding))
    
    echo "$left_padding $right_padding"
}

# Funzione per stampare separatori con stile elegante e chiusura perfetta
print_separator() {
    local title="$1"
    local color="${2:-$BLUE}"  # Default al blu se non specificato
    local width=60
    
    # Se c'è un titolo, stampa il banner completo
    if [ -n "$title" ]; then
        # Calcola il padding esatto per centrare il titolo
        local padding_info=($(calculate_padding "$title" $width))
        local left_pad=${padding_info[0]}
        local right_pad=${padding_info[1]}
        
        # Stampa il banner con padding perfetto
        echo -e "${color}"
        echo "╔$(printf '%.0s═' $(seq 1 $width))╗"
        echo "║$(printf ' %.0s' $(seq 1 $width))║"
        
        # Stampa la riga del titolo con padding dinamico
        if [ $left_pad -gt 0 ]; then
            printf "║%*s%s%*s║\n" $left_pad "" "$title" $right_pad ""
        else
            # Se il titolo è troppo lungo, stampalo senza padding
            echo "║$title║"
        fi
        
        echo "║$(printf ' %.0s' $(seq 1 $width))║"
        echo "╚$(printf '%.0s═' $(seq 1 $width))╝"
        echo -e "${NC}"
    else
        # Solo linea orizzontale
        echo -e "${color}╞$(printf '%.0s═' $(seq 1 $width))╡${NC}"
    fi
}

# Funzione per verificare l'esito di un comando con stile elegante
check_result() {
    local success_msg="$1"
    local error_msg="${2:-Errore sconosciuto}"
    local exit_code=$?
    local padding=10

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ SUCCESS: $success_msg${NC}\n"
        return 0
    else
        echo -e "\n${RED}╔══════════════════════════════════════════════════════════════╗"
        echo -e "║                     CRITICAL ERROR                     ║"
        echo -e "╠══════════════════════════════════════════════════════════╣"
        echo -e "║ $error_msg"
        echo -e "║ Exit code: $exit_code"
        echo -e "╚══════════════════════════════════════════════════════════╝${NC}\n"
        exit $exit_code
    fi
}

# Funzione per eseguire comandi con logging
run_command() {
    local cmd="$*"
    log_info "Esecuzione: $cmd"
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_success "Comando completato: $cmd"
        return 0
    else
        local exit_code=$?
        log_error "Comando fallito (exit $exit_code): $cmd"
        return $exit_code
    fi
}

# =============================================================================
# 🛡️ ENTERPRISE ERROR HANDLING SYSTEM
# =============================================================================

# Contatori globali
export ERROR_COUNT=0
export WARNING_COUNT=0
export TEMP_DIR="${TEMP_DIR:-/tmp/arch-setup-$$}"

# Funzioni di gestione errori enterprise
cleanup_on_error() {
    local exit_code=$1
    local line_number=$2
    ERROR_COUNT=$((ERROR_COUNT + 1))
    
    echo -e "\n${RED}╔══════════════════════════════════════════════════════════════╗"
    echo -e "║                    SCRIPT EXECUTION FAILED                   ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║ Error at line: $line_number"
    echo -e "║ Exit code: $exit_code"
    echo -e "║ Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Salva stato per debug
    if [[ -n "$TEMP_DIR" ]]; then
        echo "$(date): Error at line $line_number, exit code $exit_code" >> "$TEMP_DIR/error.log" 2>/dev/null || true
    fi
    
    # Cleanup risorse
    cleanup_resources
    
    # Report finale errori
    echo -e "${RED}Execution terminated with $ERROR_COUNT errors and $WARNING_COUNT warnings${NC}"
    
    exit $exit_code
}

cleanup_on_exit() {
    if (( ERROR_COUNT == 0 )); then
        if (( WARNING_COUNT > 0 )); then
            echo -e "\n${GREEN}✓ Script completed successfully with $WARNING_COUNT warnings${NC}"
        else
            echo -e "\n${GREEN}✓ Script completed successfully!${NC}"
        fi
    fi
    
    cleanup_resources
}

cleanup_on_interrupt() {
    echo -e "\n${YELLOW}⚠️ Script interrupted by user${NC}"
    cleanup_resources
    exit 130
}

cleanup_resources() {
    # Rimuovi file temporanei
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
}

# Setup trap handlers
setup_error_handling() {
    # Crea directory temporanea
    mkdir -p "$TEMP_DIR" 2>/dev/null || true
    
    # Configura trap per gestione errori
    trap 'cleanup_on_error $? $LINENO' ERR
    trap 'cleanup_on_exit' EXIT
    trap 'cleanup_on_interrupt' INT TERM
    
    # Abilita strict mode
    set -euo pipefail
}

# Inizializza il file di log con sistema avanzato
initialize_log() {
    local log_file="$1"
    
    # Crea directory log se non esiste (con fallback sicuro)
    local log_dir=$(dirname "$log_file")
    if ! mkdir -p "$log_dir" 2>/dev/null; then
        # Fallback to user home if cannot create in system location
        log_file="$HOME/.local/share/arch-bash-dev/logs/arch-setup-$(date +%Y%m%d-%H%M%S).log"
        log_dir=$(dirname "$log_file")
        mkdir -p "$log_dir" 2>/dev/null || {
            echo "Warning: Cannot create log directory, logging to console only" >&2
            return 0
        }
    fi
    
    # Crea file log con header
    {
        echo "# Arch Linux Provisioning Log"
        echo "# Started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Script: ${0##*/}"
        echo "# User: $(whoami)"
        echo "# PWD: $(pwd)"
        echo "# ============================================="
        echo ""
    } > "$log_file" 2>/dev/null || {
        echo "Warning: Cannot write to log file $log_file" >&2
        return 0
    }
    
    # Export log file path
    export LOG_FILE="$log_file"
    echo -e "${GREEN}[INFO] Log initialized: $log_file${NC}"
}