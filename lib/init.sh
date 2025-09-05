#!/bin/bash
# =============================================================================
# 🚀 INIT SCRIPT - PUNTO DI INGRESSO UNICO PER LE LIBRERIE
# =============================================================================
# Questo script centralizza l'import di tutte le librerie, garantendo
# l'ordine corretto di caricamento e un ambiente di esecuzione stabile.
# =============================================================================

# Determina la directory dello script init.sh stesso
INIT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$INIT_SCRIPT_DIR/.." && pwd)"

# Verifica che le librerie base esistano
if [[ ! -f "$INIT_SCRIPT_DIR/logging.sh" ]]; then
    echo "ERRORE: lib/logging.sh non trovato!" >&2
    exit 1
fi

# Importa le librerie nell'ordine di dipendenza corretto
# 1. Librerie di base senza dipendenze esterne
source "$INIT_SCRIPT_DIR/logging.sh"
source "$INIT_SCRIPT_DIR/system_utils.sh"

# 2. Librerie che dipendono da quelle di base
source "$INIT_SCRIPT_DIR/validation.sh"
source "$INIT_SCRIPT_DIR/ssh_utils.sh"

# 3. Librerie avanzate che dipendono da utils e logging
if [[ -f "$INIT_SCRIPT_DIR/gcloud.sh" ]]; then
    source "$INIT_SCRIPT_DIR/gcloud.sh"
fi

# 4. Carica configurazioni dopo le librerie
if [[ -f "$PROJECT_ROOT/config/settings.conf" ]]; then
    source "$PROJECT_ROOT/config/settings.conf"
else
    echo "ATTENZIONE: config/settings.conf non trovato!" >&2
fi

# Marca l'inizializzazione come completata
export LIBS_INITIALIZED=true
export PROJECT_ROOT

# Debug: Conferma inizializzazione
if [[ "${DEBUG:-false}" == "true" ]]; then
    echo "[DEBUG] Librerie inizializzate da: $INIT_SCRIPT_DIR"
    echo "[DEBUG] PROJECT_ROOT: $PROJECT_ROOT"
fi
