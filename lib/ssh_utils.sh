#!/bin/bash
# Utilities per connessioni SSH - ssh_utils.sh

# Funzione per connessione SSH alla VM
ssh_to_vm() {
    local vm_name="${1:-$VM_NAME}"
    local zone="${2:-$ZONE}"
    
    log_info "Connessione SSH a $vm_name in zona $zone..."
    gcloud compute ssh "$vm_name" --zone="$zone"
}

# Funzione per eseguire comando remoto
ssh_exec() {
    local vm_name="${1:-$VM_NAME}"
    local zone="${2:-$ZONE}"
    local command="$3"
    
    log_info "Esecuzione comando remoto su $vm_name: $command"
    gcloud compute ssh "$vm_name" --zone="$zone" --command="$command"
}

# Funzione per copiare file sulla VM
scp_to_vm() {
    local source="$1"
    local dest="$2"
    local vm_name="${3:-$VM_NAME}"
    local zone="${4:-$ZONE}"
    
    log_info "Copia di $source su $vm_name:$dest"
    gcloud compute scp "$source" "$vm_name:$dest" --zone="$zone"
}

# Funzione per copiare file dalla VM
scp_from_vm() {
    local source="$1"
    local dest="$2"
    local vm_name="${3:-$VM_NAME}"
    local zone="${4:-$ZONE}"
    
    log_info "Copia di $vm_name:$source su $dest"
    gcloud compute scp "$vm_name:$source" "$dest" --zone="$zone"
}

# Funzione per verificare connettività SSH
check_ssh_connectivity() {
    local vm_name="${1:-$VM_NAME}"
    local zone="${2:-$ZONE}"
    
    log_info "Verifica connettività SSH a $vm_name..."
    if gcloud compute ssh "$vm_name" --zone="$zone" --command="echo 'SSH OK'" &>/dev/null; then
        log_success "Connettività SSH verificata"
        return 0
    else
        log_error "Impossibile connettersi via SSH a $vm_name"
        return 1
    fi
}

# Funzione per attendere che SSH sia disponibile
wait_for_ssh() {
    local vm_name="${1:-$VM_NAME}"
    local zone="${2:-$ZONE}"
    local max_attempts="${3:-30}"
    local wait_time="${4:-10}"
    
    log_info "Attesa disponibilità SSH per $vm_name (max $max_attempts tentativi)..."
    
    for i in $(seq 1 $max_attempts); do
        if check_ssh_connectivity "$vm_name" "$zone"; then
            return 0
        fi
        log_info "Tentativo $i/$max_attempts - Attesa $wait_time secondi..."
        sleep $wait_time
    done
    
    log_error "Timeout in attesa di SSH per $vm_name"
    return 1
}