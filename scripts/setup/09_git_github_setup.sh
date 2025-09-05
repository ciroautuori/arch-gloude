
#!/bin/bash
# Script per configurazione automatica Git e GitHub - 09_git_github_setup.sh

set -e

# Trova la directory root del progetto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Carica librerie e configurazioni
source "$PROJECT_ROOT/config/settings.conf"
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/system_utils.sh"

# Inizializza log
log_file="$HOME/setup_git_github.log"
initialize_log "$log_file"

print_separator "GIT & GITHUB CONFIGURATION" "$CYAN"

# Configura Git globalmente
log_step "Configurazione Git globale..."

if [[ -n "$GIT_USERNAME" ]]; then
    git config --global user.name "$GIT_USERNAME"
    log_success "Git user.name configurato: $GIT_USERNAME"
else
    log_warning "GIT_USERNAME non definito in settings.conf"
fi

if [[ -n "$GIT_EMAIL" ]]; then
    git config --global user.email "$GIT_EMAIL"
    log_success "Git user.email configurato: $GIT_EMAIL"
else
    log_warning "GIT_EMAIL non definito in settings.conf"
fi

# Configurazioni Git aggiuntive per un workflow ottimale
log_step "Applicazione configurazioni Git avanzate..."

# Editor predefinito
git config --global core.editor "nano"

# Colori per output più leggibile
git config --global color.ui auto
git config --global color.branch auto
git config --global color.diff auto
git config --global color.status auto

# Configurazioni di sicurezza e performance
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global push.autoSetupRemote true

# Forza HTTPS per GitHub e mappa URL SSH -> HTTPS (utile per token)
git config --global url."https://github.com/".insteadOf "git@github.com:"
git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"

# Configurazione credenziali GitHub
if [[ -n "$GITHUB_TOKEN" ]]; then
    log_step "Configurazione autenticazione GitHub..."

    # Valida il token prima di usarlo (senza loggare il token)
    if command_exists curl; then
        if curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -q "^20[0-9]$"; then
            log_success "Token GitHub valido"
        else
            log_warning "Il token GitHub potrebbe essere non valido o scaduto (API /user non 2xx)"
        fi
    fi

    # Preferisci GitHub CLI come helper credenziali se disponibile
    if command_exists gh; then
        log_info "Uso GitHub CLI per configurare le credenziali Git…"
        # Login non interattivo con token
        echo "$GITHUB_TOKEN" | gh auth login --with-token --git-protocol https >/dev/null 2>&1 || true
        # Configura gh come git credential helper
        gh auth setup-git >/dev/null 2>&1 || true
        if gh auth status >/dev/null 2>&1; then
            log_success "GitHub CLI autenticato e configurato come credential helper"
        else
            log_warning "GitHub CLI non autenticato, fallback al credential helper di Git"
        fi
    fi

    # Fallback: usa git credential helper (store o libsecret) e registra le credenziali in modo corretto
    # Prova libsecret se disponibile, altrimenti ripiega su store
    if git config --global --get credential.helper | grep -q "gh auth git-credential"; then
        : # già configurato da gh
    else
        if command_exists git-credential-libsecret; then
            git config --global credential.helper libsecret
            log_info "Impostato credential.helper libsecret"
        else
            git config --global credential.helper store
            log_warning "libsecret non disponibile: uso credential.helper store (token in ~/.git-credentials)"
        fi

        # Registra le credenziali senza scrivere direttamente file in chiaro
        # Usa git credential approve per host github.com
        printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n" "$GITHUB_USERNAME" "$GITHUB_TOKEN" | git credential approve
        log_success "Credenziali GitHub registrate per github.com"
    fi
else
    log_warning "GITHUB_TOKEN non definito in settings.conf - Skip autenticazione GitHub"
fi

# Configura GitHub CLI se installato
# Configura GitHub CLI se installato (stato finale)
if command_exists gh; then
    log_step "Verifica stato GitHub CLI…"
    if gh auth status &>/dev/null; then
        log_success "GitHub CLI: autenticato"
        gh auth status 2>&1 | grep "Logged in" | head -1 | sed 's/^/  → /'
    else
        log_warning "GitHub CLI: non autenticato"
    fi
else
    log_info "GitHub CLI non installato - Skip configurazione"
fi

# Verifica configurazione finale
log_step "Verifica configurazione Git..."

echo ""
echo "=== CONFIGURAZIONE GIT ATTUALE ==="
echo "User Name:    $(git config --global user.name 2>/dev/null || echo 'NON CONFIGURATO')"
echo "User Email:   $(git config --global user.email 2>/dev/null || echo 'NON CONFIGURATO')"
echo "Default Branch: $(git config --global init.defaultBranch 2>/dev/null || echo 'NON CONFIGURATO')"
echo "Credential Helper: $(git config --global credential.helper 2>/dev/null || echo 'NON CONFIGURATO')"

if command_exists gh && gh auth status &>/dev/null; then
    echo "GitHub CLI:   ✓ AUTENTICATO"
else
    echo "GitHub CLI:   ✗ NON AUTENTICATO"
fi

echo "=================================="
echo ""

log_success "Configurazione Git e GitHub completata!"

print_separator "" "$GREEN"
