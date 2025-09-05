#!/bin/bash
# =============================================================================
# 🔧 gcloud.sh - Funzioni Helper per Google Cloud SDK
# =============================================================================

# Carica dipendenze se non già caricate
if [[ -z "$SCRIPT_DIR" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/system_utils.sh"
    source "$PROJECT_ROOT/config/settings.conf"
fi

# =============================================================================
# ☁️ FUNZIONI HELPER PER GOOGLE CLOUD SDK
# =============================================================================

# Funzione per eseguire comandi con timeout
execute_with_timeout() {
    local timeout=${TIMEOUT:-30}
    timeout "$timeout" "$@"
}

# Funzione per retry con backoff
retry_with_backoff() {
    local max_attempts=3
    local delay=1
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_warning "Tentativo $attempt fallito, riprovo in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
        fi
        
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Banner header con stile elegante
log_header() {
    print_separator "$1" "$CYAN"
}

# Verifica permessi IAM utente
check_iam_permissions() {
    log_step "Verifica permessi IAM utente..."
    local user_email
    user_email=$(gcloud config get-value account)
    local project_id
    project_id=$(gcloud config get-value project)

    if [[ -z "$user_email" ]] || [[ -z "$project_id" ]]; then
        log_error "Impossibile ottenere utente o progetto corrente. Verifica la configurazione di gcloud."
        exit 1
    fi

    log_info "Utente: $user_email, Progetto: $project_id"

    local iam_policy
    if ! iam_policy=$(gcloud projects get-iam-policy "$project_id" --format=json 2>/dev/null); then
        log_error "Impossibile ottenere i permessi IAM per il progetto '$project_id'."
        log_info "Assicurati che l'API Cloud Resource Manager sia abilitata."
        exit 1
    fi

    if echo "$iam_policy" | jq -e --arg user "user:$user_email" '.bindings[] | select(.role == "roles/owner" and (.members | index($user)))' > /dev/null; then
        log_success "L'utente è 'Owner' del progetto. Permessi sufficienti."
        return 0
    fi

    local has_os_admin_login
    has_os_admin_login=$(echo "$iam_policy" | jq -e --arg user "user:$user_email" '.bindings[] | select(.role == "roles/compute.osAdminLogin" and (.members | index($user)))' > /dev/null && echo "true" || echo "false")
    
    local has_service_account_user
    has_service_account_user=$(echo "$iam_policy" | jq -e --arg user "user:$user_email" '.bindings[] | select(.role == "roles/iam.serviceAccountUser" and (.members | index($user)))' > /dev/null && echo "true" || echo "false")

    if [[ "$has_os_admin_login" == "true" && "$has_service_account_user" == "true" ]]; then
        log_success "L'utente ha i ruoli necessari (Compute OS Admin Login, Service Account User)."
    else
        log_error "Permessi IAM insufficienti. L'utente deve essere 'Owner' o avere i ruoli 'Compute OS Admin Login' e 'Service Account User'."
        [[ "$has_os_admin_login" == "false" ]] && log_info "- Manca: 'Compute OS Admin Login'"
        [[ "$has_service_account_user" == "false" ]] && log_info "- Manca: 'Service Account User'"
        exit 1
    fi
}

# Inizializza variabili GCP se non definite
export GCP_OS_LOGIN_USER
GCP_OS_LOGIN_USER="$(gcloud config get-value account 2>/dev/null | sed 's/@/\_/' | tr '.-' '__')"
GCP_PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
GCP_ZONE="${ZONE}"
VM_SERVICE_ACCOUNT="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}-compute@developer.gserviceaccount.com"
VM_SCOPES="https://www.googleapis.com/auth/cloud-platform"
VM_TAGS="${TAGS}"
VM_IMAGE_PROJECT="arch-linux-gce"
VM_IMAGE_FAMILY="arch"

health_check_prerequisites() {
    log_header "HEALTH CHECK PREREQUISITI"
    
    log_step "Verifica installazione gcloud..."
    if ! command -v gcloud &> /dev/null; then
        log_error "'gcloud' non trovato. Installa Google Cloud SDK."
        exit 1
    fi
    log_success "gcloud trovato"
    
    log_step "Verifica autenticazione gcloud..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "Nessun account gcloud attivo. Esegui 'gcloud auth login'."
        exit 1
    fi
    log_success "Utente autenticato: $(gcloud config get-value account)"
    
    log_step "Verifica configurazione progetto gcloud..."
    if ! gcloud config get-value project &> /dev/null; then
        log_error "Nessun progetto gcloud configurato. Esegui 'gcloud config set project NOME_PROGETTO'."
        exit 1
    fi
    log_success "Progetto configurato: $(gcloud config get-value project)"
    
    log_step "Verifica abilitazione API Compute Engine..."
    if ! gcloud services list --enabled --filter="name:compute.googleapis.com" --format="value(name)" | grep -q .; then
        log_error "API Compute Engine non abilitata per il progetto."
        log_info "Abilitala con: gcloud services enable compute.googleapis.com"
        exit 1
    fi
    log_success "API Compute Engine abilitata"

    log_step "Verifica dipendenza (jq)..."
    if ! command -v jq &> /dev/null; then
        log_error "'jq' non trovato. È necessario per la verifica dei permessi IAM."
        log_info "Installalo con 'sudo pacman -S jq' o il package manager della tua distribuzione."
        exit 1
    fi
    log_success "jq trovato"

    check_iam_permissions
}

# Health check post-creazione VM
health_check_vm() {
    log_header "HEALTH CHECK POST-CREAZIONE VM"
    log_step "Attesa avvio completo della VM (60s)..."
    execute_with_timeout sleep 60

    log_step "Verifica connettività SSH..."
    if ! execute_with_timeout gcloud compute ssh "$VM_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT_ID" --command "echo 'Connessione SSH OK'" --quiet; then
        log_error "Health check fallito: impossibile connettersi via SSH."
        exit 1
    fi
    log_success "Connettività SSH verificata."

    log_step "Verifica stato istanza..."
    local status
    status=$(gcloud compute instances describe "$VM_NAME" --zone "$GCP_ZONE" --project "$GCP_PROJECT_ID" --format='value(status)')
    if [[ "$status" == "RUNNING" ]]; then
        log_success "Stato istanza: $status"
    else
        log_error "Stato istanza non è RUNNING. Stato attuale: $status"
        exit 1
        return 1
    fi
}

# Funzione generica per menu di selezione
select_from_menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected_option=""

    PS3="$prompt"
    select opt in "${options[@]}"; do
        if [[ -n "$opt" ]]; then
            selected_option="$opt"
            break
        else
            log_warning "Selezione non valida. Riprova."
        fi
    done
    # Ritorna solo la selezione, senza il prompt
    echo "${selected_option:-}"
}

# Configurazione VM personalizzata
configure_custom_vm() {
    log_header "CONFIGURAZIONE PERSONALIZZATA"

    # Selezione Regione
    local regions
    regions=($(gcloud compute regions list --format="value(name)"))
    GCP_REGION=$(select_from_menu "Seleziona una regione: " "${regions[@]}")

    # Selezione Zona
    local zones
    zones=($(gcloud compute zones list --filter="region:($GCP_REGION)" --format="value(name)"))
    GCP_ZONE=$(select_from_menu "Seleziona una zona in '$GCP_REGION': " "${zones[@]}")

    # Selezione Tipo Macchina
    local machine_types
    local machine_types_raw
    if ! machine_types_raw=$(gcloud compute machine-types list --filter="zone:($GCP_ZONE)" --format="value(name)" 2>/dev/null); then
        log_error "Errore nel recupero dei tipi macchina da gcloud. Controlla la connessione o riprova più tardi."
        exit 1
    fi
    readarray -t machine_types <<< "$machine_types_raw"
    if [[ ${#machine_types[@]} -eq 0 ]]; then
        log_error "Nessun tipo macchina restituito da gcloud. Interruzione."
        exit 1
    fi
    VM_MACHINE_TYPE=$(select_from_menu "Seleziona un tipo di macchina per la zona '$GCP_ZONE': " "${machine_types[@]}")

    # Selezione Dimensione Disco
    read -p "Inserisci la dimensione del disco di boot (es. 50GB): " VM_BOOT_DISK_SIZE
    # Validazione input dimensione disco
    if [[ -z "$VM_BOOT_DISK_SIZE" ]]; then
        # Invio senza input -> default
        VM_BOOT_DISK_SIZE="30GB"
    elif [[ "$VM_BOOT_DISK_SIZE" =~ ^[0-9]+$ ]]; then
        # Solo numero -> assume GB
        VM_BOOT_DISK_SIZE="${VM_BOOT_DISK_SIZE}GB"
    elif [[ "$VM_BOOT_DISK_SIZE" =~ ^[0-9]+[Gg][Bb]$ ]]; then
        # Numero seguito da GB/gB/Gb/gb -> normalizza a maiuscolo
        VM_BOOT_DISK_SIZE="${VM_BOOT_DISK_SIZE^^}"  # upper-case
    else
        # Formato non riconosciuto
        log_warning "Formato non valido, usando default 30GB."
        VM_BOOT_DISK_SIZE="30GB"
    fi
}

# Menu di selezione configurazione VM
show_vm_configuration_menu() {
    log_header "🏗️ CONFIGURAZIONE VM ARCH LINUX GCP"

    echo "Seleziona la configurazione VM:"
    local options=(
        "Free Tier Micro (USA) - e2-micro, 30GB, us-west1-b"
        "Standard Bilanciata (EU) - e2-standard-2, 50GB, europe-west1-b"
        "High Performance (EU) - n2-standard-4, 100GB, europe-west3-c"
        "Personalizzata"
        "Esci"
    )
    
    local choice
    choice=$(select_from_menu "Scegli un'opzione: " "${options[@]}")

    case "$choice" in
        "${options[0]}")
            GCP_ZONE="us-west1-b"
            VM_MACHINE_TYPE="e2-micro"
            VM_BOOT_DISK_SIZE="30GB"
            ;;
        "${options[1]}")
            GCP_ZONE="europe-west1-b"
            VM_MACHINE_TYPE="e2-standard-2"
            VM_BOOT_DISK_SIZE="50GB"
            ;;
        "${options[2]}")
            GCP_ZONE="europe-west3-c"
            VM_MACHINE_TYPE="n2-standard-4"
            VM_BOOT_DISK_SIZE="100GB"
            ;;
        "${options[3]}")
            configure_custom_vm
            ;;
        "${options[4]}")
            log_info "Operazione annullata dall'utente."
            exit 0
            ;;
    esac
}

# Configura IAM e OS Login
configure_iam_and_os_login() {
    log_header "CONFIGURAZIONE PERMESSI IAM"

    log_step "Abilitazione OS Login a livello di progetto..."
    execute_with_timeout gcloud compute project-info add-metadata --metadata enable-oslogin=TRUE --project="$GCP_PROJECT_ID"
    log_success "OS Login abilitato a livello di progetto."

    local user_account
    user_account=$(gcloud config get-value account)

    log_step "Assegnazione ruolo 'Compute OS Admin Login' a $user_account..."
    execute_with_timeout gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="user:$user_account" --role="roles/compute.osAdminLogin"
    log_success "Ruolo 'Compute OS Admin Login' assegnato."

    log_step "Assegnazione ruolo 'Service Account User' a $user_account..."
    execute_with_timeout gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="user:$user_account" --role="roles/iam.serviceAccountUser"
    log_success "Ruolo 'Service Account User' assegnato."
}

# Pulisce VM esistente con gestione intelligente dei conflitti
cleanup_existing_vm() {
    log_header "VERIFICA VM ESISTENTE"
    
    if gcloud compute instances describe "$VM_NAME" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" &>/dev/null; then
        log_warning "VM '$VM_NAME' già esistente nella zona $GCP_ZONE"
        
        if [ "${DRY_RUN:-false}" = true ]; then
            log_info "[DRY RUN] VM esistente rilevata, simulazione gestione conflitto"
            return 0
        fi

        if [ "${NON_INTERACTIVE:-false}" = true ]; then
            # Modalità automatica: elimina sempre senza chiedere
            log_info "Modalità automatica: eliminazione VM esistente..."
            if gcloud compute instances delete "$VM_NAME" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --quiet; then
                log_success "VM '$VM_NAME' eliminata automaticamente"
            else
                log_error "Eliminazione automatica della VM fallita"
                return 1
            fi
        else
            # Modalità interattiva: offri opzioni intelligenti
            echo ""
            echo "Gestione VM esistente - Scegli un'opzione:"
            echo "1) Elimina VM esistente e ricrea con stesso nome"
            echo "2) Cambia nome VM e crea nuova istanza (mantiene l'esistente)"
            echo "3) Annulla operazione"
            echo ""
            
            while true; do
                read -p "Scegli opzione (1-3): " choice
                case $choice in
                    1)
                        log_info "Eliminazione VM '$VM_NAME' in corso..."
                        if gcloud compute instances delete "$VM_NAME" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" --quiet; then
                            log_success "VM '$VM_NAME' eliminata con successo"
                            break
                        else
                            log_error "Eliminazione della VM fallita"
                            return 1
                        fi
                        ;;
                    2)
                        echo ""
                        read -p "Inserisci nuovo nome per la VM: " new_vm_name
                        if [[ -z "$new_vm_name" ]]; then
                            log_warning "Nome non valido, riprova"
                            continue
                        fi
                        
                        # Verifica che il nuovo nome non esista già
                        if gcloud compute instances describe "$new_vm_name" --zone="$GCP_ZONE" --project="$GCP_PROJECT_ID" &>/dev/null; then
                            log_warning "VM '$new_vm_name' esiste già! Scegli un altro nome."
                            continue
                        fi
                        
                        # Aggiorna il nome VM globalmente
                        VM_NAME="$new_vm_name"
                        export VM_NAME
                        log_success "Nuovo nome VM impostato: $VM_NAME"
                        log_info "VM esistente '$VM_NAME' mantenuta, creazione di '$new_vm_name'"
                        break
                        ;;
                    3)
                        log_info "Operazione annullata dall'utente"
                        exit 0
                        ;;
                    *)
                        log_warning "Opzione non valida. Scegli 1, 2 o 3."
                        ;;
                esac
            done
        fi
    else
        log_info "Nessuna VM con nome '$VM_NAME' trovata. Creazione di nuova VM."
    fi
    return 0
}

# Crea nuova VM
create_new_vm() {
    log_header "CREAZIONE NUOVA VM"
    log_info "Zona: $GCP_ZONE, Tipo Macchina: $VM_MACHINE_TYPE, Disco: $VM_BOOT_DISK_SIZE"

    # Costruisce il comando come un array per gestire correttamente gli spazi e gli argomenti.
    # Questa è la soluzione robusta per l'errore 'File name too long'.
    local -a create_cmd_args=(
        gcloud compute instances create "$VM_NAME"
        --project="$GCP_PROJECT_ID"
        --zone="$GCP_ZONE"
        --machine-type="$VM_MACHINE_TYPE"
        --network-interface=network-tier=PREMIUM,subnet=default
        --metadata=enable-oslogin=true
        --maintenance-policy=MIGRATE
        --provisioning-model=STANDARD
        --service-account="$VM_SERVICE_ACCOUNT"
        --scopes="$VM_SCOPES"
        --tags="$VM_TAGS"
        --image-project="$VM_IMAGE_PROJECT"
        --image-family="$VM_IMAGE_FAMILY"
        --boot-disk-size="$VM_BOOT_DISK_SIZE"
        --boot-disk-type=pd-ssd
        --no-shielded-secure-boot
        --shielded-vtpm
        --shielded-integrity-monitoring
    )

    # In modalità DRY_RUN, stampa il comando che verrebbe eseguito
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Il seguente comando verrebbe eseguito:"
        echo "    ${create_cmd_args[@]}"
        # Simula successo in dry-run
        log_success "[DRY RUN] Creazione VM '$VM_NAME' simulata con successo."
        return 0
    fi

    # Esegue il comando passando l'array di argomenti
    if execute_with_timeout "${create_cmd_args[@]}"; then
        log_success "VM '$VM_NAME' creata con successo."
    else
        log_error "Creazione della VM '$VM_NAME' fallita."
        return 1
    fi
}

# Testa accesso sudo
test_sudo_access() {
    log_header "TEST ACCESSO SUDO"
    log_step "Tentativo di eseguire 'sudo whoami' sulla VM..."
    
    local sudo_test_command="gcloud compute ssh $VM_NAME --zone=$GCP_ZONE --project=$GCP_PROJECT_ID --command='sudo whoami'"
    
    if retry_with_backoff eval "$sudo_test_command" | grep -q 'root'; then
        log_success "Test sudo superato. L'utente può eseguire comandi come root."
    else
        log_error "Test sudo fallito. Verifica la configurazione di OS Login e i permessi IAM."
        exit 1
    fi
}
