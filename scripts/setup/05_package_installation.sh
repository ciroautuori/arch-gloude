#!/bin/bash
# Installazione pacchetti - 05_package_installation.sh

set -e

# Carica configurazioni e librerie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config/settings.conf"
source "$SCRIPT_DIR/../../config/packages.conf"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/system_utils.sh"

print_separator "INSTALLAZIONE PACCHETTI"

# Verifica di essere root
check_root

log_step "Installazione pacchetti essenziali..."

# Installa tutti i pacchetti definiti in packages.conf
log_info "Installazione di ${#ALL_PACKAGES[@]} pacchetti..."

# Mostra lista pacchetti
log_info "Pacchetti da installare:"
for pkg in "${ALL_PACKAGES[@]}"; do
    echo "  - $pkg"
done

# Installazione
sudo pacman -S --noconfirm "${ALL_PACKAGES[@]}"

check_result "Tutti i pacchetti installati con successo" "Errore nell'installazione dei pacchetti"

# Verifica installazione pacchetti critici
log_step "Verifica installazione pacchetti critici..."

critical_packages=("docker" "docker-compose" "sudo" "git")
all_ok=true

for pkg in "${critical_packages[@]}"; do
    if package_installed "$pkg"; then
        log_success "$pkg installato correttamente"
    else
        log_error "$pkg non installato"
        all_ok=false
    fi
done

if [ "$all_ok" = false ]; then
    log_error "Alcuni pacchetti critici non sono stati installati"
    exit 1
fi

# Verifica versioni
log_info "Versioni pacchetti principali:"
if command_exists docker; then
    echo "  Docker: $(docker --version 2>/dev/null || echo 'non disponibile')"
fi
if command_exists docker-compose; then
    echo "  Docker Compose: $(docker-compose --version 2>/dev/null || echo 'non disponibile')"
fi
if command_exists git; then
    echo "  Git: $(git --version 2>/dev/null || echo 'non disponibile')"
fi

print_separator "INSTALLAZIONE PACCHETTI COMPLETATA"
