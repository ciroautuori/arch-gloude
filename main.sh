#!/bin/bash
# Main orchestrator - main.sh
# Script principale per il provisioning completo di Arch Linux + Docker su Google Cloud

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directory base dello script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carica configurazioni
source "$SCRIPT_DIR/config/settings.conf"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Inizializza log
initialize_log

# Banner principale
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║            ARCH LINUX + DOCKER PROVISIONING                  ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Funzione per mostrare il menu principale
show_menu() {
    echo -e "${YELLOW}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║                    ARCH LINUX + SETUP FULL                   ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "1) Provisioning completo (crea VM + setup + verifica)"
    echo "2) Solo creazione VM"
    echo "3) Solo setup VM (VM già esistente)"
    echo "4) Solo verifica VM"
    echo "5) Setup remoto (esegui setup da locale su VM remota)"
    echo "6) Mostra configurazione corrente"
    echo "7) Esci"
    echo ""
}

# Funzione per mostrare la configurazione
show_config() {
    echo -e "${CYAN}=== CONFIGURAZIONE CORRENTE ===${NC}"
    echo "Project ID: $PROJECT_ID"
    echo "Zona: $ZONE"
    echo "Nome VM: $VM_NAME"
    echo "Tipo macchina: $MACHINE_TYPE"
    echo "Dimensione disco: $DISK_SIZE"
    echo "Tipo disco: $DISK_TYPE"
    echo "Immagine: $IMAGE_FAMILY / $IMAGE_PROJECT"
    echo "Tag rete: ${NETWORK_TAGS[@]}"
    echo ""
}

# Funzione per il provisioning completo
full_provisioning() {
    log_step "PROVISIONING COMPLETO"
    
    # Step 1: Crea VM
    log_info "Step 1/4: Creazione VM..."
    bash "$SCRIPT_DIR/scripts/create_vm.sh" --auto
    check_result "VM creata con successo" "Errore nella creazione VM"
    
    # Attesa minima per avvio VM
    sleep 15
    
    # Step 2: Setup VM (esecuzione remota automatica)
    log_info "Step 2/4: Setup VM (automatico)..."
    bash "$SCRIPT_DIR/scripts/setup_vm.sh" "$VM_NAME" "$ZONE" "true"
    
    # Step 3: Riavvio VM (necessario per attivare i gruppi Docker)
    log_info "Step 3/4: Riavvio VM per attivare configurazioni..."
    gcloud compute instances reset "$VM_NAME" --zone="$ZONE" --quiet
    log_info "VM riavviata, attesa riconnessione..."
    sleep 25  # Attesa ottimizzata per riavvio
    
    # Step 4: Verifica finale (dopo riavvio)
    log_info "Step 4/4: Verifica installazione post-riavvio..."
    # Usa path assoluto alla home utente per il file di verifica
    gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="bash ~/arch-bash-dev/scripts/verify_vm.sh"
    
    log_success "PROVISIONING COMPLETATO!"
}

# Verifica prerequisiti (veloce)
check_prerequisites || exit 1

# Modalità automatica: se il primo argomento è --auto, esegui provisioning completo senza menu
if [ "$1" == "--auto" ]; then
    full_provisioning
    exit 0
fi

# Loop menu principale
while true; do
    show_menu
    read -p "Seleziona opzione (1-7): " choice
    echo ""
    
    case $choice in
        1)
            full_provisioning
            ;;
        2)
            log_step "CREAZIONE VM"
            bash "$SCRIPT_DIR/scripts/create_vm.sh"
            ;;
        3)
            log_step "SETUP VM"
            # Esecuzione automatica remota senza chiedere
            log_info "Esecuzione setup remoto automatico..."
            bash "$SCRIPT_DIR/scripts/setup_vm.sh" "$VM_NAME" "$ZONE" "true"
            ;;
        4)
            log_step "VERIFICA VM"
            echo "Eseguire verifica remota o locale?"
            echo "1) Remota (esegui da qui sulla VM)"
            echo "2) Locale (devi essere già sulla VM)"
            read -p "Scelta (1/2): " verify_type
            
            if [ "$verify_type" = "1" ]; then
                gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="bash -s" < "$SCRIPT_DIR/scripts/verify_vm.sh"
            else
                bash "$SCRIPT_DIR/scripts/verify_vm.sh"
            fi
            ;;
        5)
            log_step "SETUP REMOTO"
            bash "$SCRIPT_DIR/scripts/setup_vm.sh" "$VM_NAME" "$ZONE" "true"
            ;;
        6)
            show_config
            ;;
        7)
            log_info "Uscita..."
            echo -e "${GREEN}Grazie per aver usato Arch Linux Provisioning!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opzione non valida${NC}"
            ;;
    esac
    
    echo ""
    read -p "Premi INVIO per continuare..."
    clear
done
