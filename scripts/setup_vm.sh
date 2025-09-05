#!/bin/bash
# Orchestratore setup completo VM - setup_vm.sh

set -e

# Carica configurazioni e librerie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/settings.conf"
source "$SCRIPT_DIR/../lib/logging.sh"
source "$SCRIPT_DIR/../lib/ssh_utils.sh"
source "$SCRIPT_DIR/../lib/validation.sh"

# Inizializza log
initialize_log

print_separator "SETUP COMPLETO VM ARCH LINUX"

# Verifica prerequisiti
check_prerequisites || exit 1

# Parametri opzionali
VM_NAME="${1:-$VM_NAME}"
ZONE="${2:-$ZONE}"
REMOTE_EXEC="${3:-false}"  # Se true, esegue gli script sulla VM remota

log_info "VM Target: $VM_NAME in zona $ZONE"

# Verifica se la VM esiste
if ! vm_exists "$VM_NAME" "$ZONE"; then
    log_error "La VM $VM_NAME non esiste in zona $ZONE"
    log_info "Esegui prima: $SCRIPT_DIR/create_vm.sh"
    exit 1
fi

# Verifica stato VM
status=$(check_vm_status "$VM_NAME" "$ZONE")
if [ "$status" != "RUNNING" ]; then
    log_error "La VM non è in esecuzione (stato: $status)"
    exit 1
fi

log_success "VM trovata e in esecuzione"

# Array degli script di setup da eseguire in sequenza
SETUP_SCRIPTS=(
    "01_system_config.sh"
    "02_system_update.sh"
    "03_dbus_fix.sh"
    "04_mirror_optimization.sh"
    "05_package_installation.sh"
    "06_user_setup.sh"
    "07_environment_setup.sh"
    "08_system_restart.sh"
    "09_git_github_setup.sh"
)

if [ "$REMOTE_EXEC" = "true" ]; then
    log_step "Esecuzione remota degli script di setup..."
    
    # Copia tutti gli script sulla VM nella home directory
    log_info "Copia degli script sulla VM..."
    REMOTE_DIR="arch-bash-dev"
    
    # Rimuovi directory esistente se presente
    ssh_exec "$VM_NAME" "$ZONE" "rm -rf $REMOTE_DIR"
    
    # Copia l'intera struttura direttamente nella home
    # Usa il percorso completo per evitare ambiguità
    gcloud compute scp --recurse "$SCRIPT_DIR/.." "$VM_NAME:~/$REMOTE_DIR" --zone="$ZONE"
    check_result "Script copiati sulla VM" "Errore nella copia degli script"
    
    # Verifica struttura copiata
    ssh_exec "$VM_NAME" "$ZONE" "ls -la ~/arch-bash-dev/"
    
    # Esegui ogni script in sequenza sulla VM
    for script in "${SETUP_SCRIPTS[@]}"; do
        log_step "Esecuzione remota: $script"
        # Il path è ora ~/arch-bash-dev/scripts/setup/$script
        REMOTE_SCRIPT_PATH="~/arch-bash-dev/scripts/setup/$script"
        
        # Verifica che lo script esista
        if ssh_exec "$VM_NAME" "$ZONE" "test -f $REMOTE_SCRIPT_PATH"; then
            ssh_exec "$VM_NAME" "$ZONE" "sudo bash $REMOTE_SCRIPT_PATH"
            check_result "$script completato" "Errore in $script"
        else
            log_error "Script non trovato: $REMOTE_SCRIPT_PATH"
            ssh_exec "$VM_NAME" "$ZONE" "find ~/arch-bash-dev -name '$script' -type f"
            exit 1
        fi
    done
    
    log_success "Setup remoto completato"
else
    log_step "Esecuzione locale degli script di setup..."
    log_warning "NOTA: Questo script dovrebbe essere eseguito SULLA VM, non localmente!"
    
    read -p "Sei sicuro di voler continuare localmente? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operazione annullata"
        log_info "Per eseguire il setup sulla VM, usa:"
        echo "  1. Connettiti: gcloud compute ssh $VM_NAME --zone=$ZONE"
        echo "  2. Clona o copia questo repository sulla VM"
        echo "  3. Esegui: sudo bash scripts/setup_vm.sh"
        exit 0
    fi
    
    # Esegui ogni script in sequenza
    for script in "${SETUP_SCRIPTS[@]}"; do
        script_path="$SCRIPT_DIR/setup/$script"
        
        if [ ! -f "$script_path" ]; then
            log_error "Script non trovato: $script_path"
            exit 1
        fi
        
        log_step "Esecuzione: $script"
        
        # Gli script 01-06 e 08 richiedono sudo
        if [[ "$script" != "07_environment_setup.sh" ]]; then
            sudo bash "$script_path"
        else
            # 07 deve essere eseguito come utente normale
            bash "$script_path"
        fi
        
        check_result "$script completato" "Errore in $script"
        
        # Pausa tra gli script per permettere la lettura dei log
        if [[ "$script" != "08_system_restart.sh" ]]; then
            sleep 2
        fi
    done
    
    log_success "Setup locale completato"
fi

print_separator "SETUP COMPLETATO CON SUCCESSO"

echo ""
echo "=== PROSSIMI PASSI ==="
echo "1. Se non hai riavviato, riavvia la VM:"
echo "   gcloud compute instances reset $VM_NAME --zone=$ZONE"
echo ""
echo "2. Dopo il riavvio, verifica l'installazione:"
echo "   gcloud compute ssh $VM_NAME --zone=$ZONE"
echo "   bash scripts/verify_vm.sh"
echo ""
echo "3. Per utilizzare Docker senza sudo:"
echo "   newgrp docker"
echo "   O fai logout/login"
echo ""

log_info "Log completo salvato in: $LOG_FILE"