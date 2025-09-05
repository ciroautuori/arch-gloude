#!/bin/bash
# Script per creazione VM su Google Cloud - create_vm.sh

set -e

# Carica configurazioni e librerie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/settings.conf"
source "$SCRIPT_DIR/../lib/logging.sh"
source "$SCRIPT_DIR/../lib/validation.sh"
source "$SCRIPT_DIR/../lib/system_utils.sh"

# Inizializza log
initialize_log

print_separator "CREAZIONE VM GOOGLE CLOUD"

# Verifica prerequisiti
check_prerequisites || exit 1

# Gestione flag --auto
AUTO_MODE=false
if [ "$1" == "--auto" ]; then
    AUTO_MODE=true
    shift  # Rimuovi --auto dagli argomenti
fi

# Parametri opzionali da linea di comando
VM_NAME="${1:-$VM_NAME}"
ZONE="${2:-$ZONE}"

# Validazione parametri
validate_vm_name "$VM_NAME" || exit 1

# Verifica se la VM esiste già
if vm_exists "$VM_NAME" "$ZONE"; then
    log_warning "La VM $VM_NAME esiste già in zona $ZONE"
    # In modalità automatica, elimina senza chiedere
    if [ "$AUTO_MODE" == "true" ]; then
        log_info "Modalità automatica: eliminazione VM esistente"
        gcloud compute instances delete "$VM_NAME" \
            --zone="$ZONE" \
            --quiet
        log_success "VM eliminata"
    else
        read -p "Vuoi eliminarla e ricrearla? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            gcloud compute instances delete "$VM_NAME" \
                --zone="$ZONE" \
                --quiet
            log_success "VM eliminata"
        else
            log_info "Operazione annullata"
            exit 0
        fi
    fi
fi

# Creazione VM
log_step "Creazione VM $VM_NAME..."

gcloud compute instances create "$VM_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --image-project="$IMAGE_PROJECT" \
    --image-family="$IMAGE_FAMILY" \
    --machine-type="$MACHINE_TYPE" \
    --boot-disk-size="$BOOT_DISK_SIZE" \
    --boot-disk-type="$BOOT_DISK_TYPE" \
    --boot-disk-device-name="$VM_NAME" \
    --can-ip-forward \
    --metadata="$VM_METADATA" \
    --tags="$VM_TAGS"

check_result "VM creata con successo" "Errore nella creazione della VM"

# Attendi che la VM sia pronta
log_info "Attesa avvio VM..."
sleep 10

# Verifica stato VM
status=$(check_vm_status "$VM_NAME" "$ZONE")
if [ "$status" = "RUNNING" ]; then
    log_success "VM in esecuzione"
else
    log_error "VM in stato: $status"
    exit 1
fi

# Ottieni IP esterno
EXTERNAL_IP=$(gcloud compute instances describe "$VM_NAME" \
    --zone="$ZONE" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

log_success "VM creata con IP esterno: $EXTERNAL_IP"

# Salva informazioni VM
cat > /tmp/vm_info.txt <<EOF
VM_NAME=$VM_NAME
ZONE=$ZONE
EXTERNAL_IP=$EXTERNAL_IP
PROJECT_ID=$PROJECT_ID
CREATED_AT=$(date)
EOF

log_info "Informazioni VM salvate in /tmp/vm_info.txt"

print_separator "VM CREATA CON SUCCESSO"
