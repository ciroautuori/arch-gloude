#!/bin/bash
# Setup ambiente di sviluppo - 07_environment_setup.sh

set -e

# Carica configurazioni e librerie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config/settings.conf"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/system_utils.sh"

print_separator "SETUP AMBIENTE DI SVILUPPO"

# NON deve essere eseguito come root per configurare l'ambiente utente
if [[ $EUID -eq 0 ]]; then
    log_warning "Questo script configura l'ambiente utente, eseguendolo come utente normale..."
    REAL_USER=$(get_real_user)
    REAL_HOME=$(get_real_home)
    
    # Rieseggi come utente normale
    # Usa la home dell'utente per i log invece di /tmp
    USER_LOG_FILE="$REAL_HOME/arch-setup-$(date +%Y%m%d-%H%M%S).log"
    sudo -u "$REAL_USER" bash -c "LOG_FILE='$USER_LOG_FILE' REAL_USER='$REAL_USER' REAL_HOME='$REAL_HOME' bash '$0'"
    exit $?
fi

log_step "Installazione Starship prompt..."

# Verifica se Starship è già installato
if command_exists starship; then
    log_success "Starship già installato: $(starship --version)"
else
    log_info "Download e installazione Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    check_result "Starship installato" "Errore nell'installazione di Starship"
fi

log_step "Configurazione shell..."

# Determina quale shell è in uso
CURRENT_SHELL=$(basename "$SHELL")
log_info "Shell corrente: $CURRENT_SHELL"

# Configura per Bash
if [ "$CURRENT_SHELL" = "bash" ] || [ -f ~/.bashrc ]; then
    log_info "Configurazione Bash..."
    
    # Aggiungi Starship a .bashrc se non presente
    if ! grep -q "starship init bash" ~/.bashrc 2>/dev/null; then
        echo 'eval "$(starship init bash)"' >> ~/.bashrc
        log_success "Starship aggiunto a .bashrc"
    else
        log_info "Starship già configurato in .bashrc"
    fi
fi

# Configura per Zsh
if [ "$CURRENT_SHELL" = "zsh" ] || [ -f ~/.zshrc ]; then
    log_info "Configurazione Zsh..."
    
    # Aggiungi Starship a .zshrc se non presente
    if ! grep -q "starship init zsh" ~/.zshrc 2>/dev/null; then
        echo 'eval "$(starship init zsh)"' >> ~/.zshrc
        log_success "Starship aggiunto a .zshrc"
    else
        log_info "Starship già configurato in .zshrc"
    fi
fi

# Crea configurazione Starship personalizzata
log_info "Creazione configurazione Starship..."
mkdir -p ~/.config

if [ ! -f ~/.config/starship.toml ]; then
    cat > ~/.config/starship.toml << 'EOF'
# Configurazione Starship completa e personalizzata
format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$docker_context\
$cmd_duration\
$time\
$line_break\
$character"""

[character]
success_symbol = "[➜](bold green) "
error_symbol = "[➜](bold red) "

[directory]
truncation_length = 3
truncate_to_repo = true

[hostname]
format = " 🐍 [$hostname](bold blue) "
ssh_only = false
disabled = false

[username]
format = "👾 [$user](bold yellow)@"
show_always = true
disabled = false

[git_branch]
symbol = "🌱 "
format = "on [$symbol$branch]($style) "

[git_status]
format = '([\[$all_status$ahead_behind\]]($style) )'

[docker_context]
format = "🐳 [$context](blue bold) "
only_with_files = false
disabled = false

[cmd_duration]
min_time = 2000
format = "⏱️  [$duration](bold yellow) "
show_milliseconds = false

[time]
disabled = false
format = "🕐 [$time](bold white) "
time_format = "%H:%M"
use_12hr = false

[package]
disabled = true

[nodejs]
format = "via [⬢ $version](bold green) "

[python]
format = 'via [🐍 ${pyenv_prefix}(${version} )(\($virtualenv\) )]($style)'

[rust]
format = "via [🦀 $version](red bold) "

[golang]
format = "via [🐹 $version](bold cyan) "

[java]
format = "via [☕ $version](red dimmed) "

[memory_usage]
disabled = false
threshold = 75
format = "via $symbol [${ram_pct}](bold dimmed) "

[battery]
full_symbol = "🔋 "
charging_symbol = "⚡️ "
discharging_symbol = "💀 "

[[battery.display]]
threshold = 30
style = "bold red"
EOF
    log_success "Configurazione Starship creata con tema completo"
else
    log_info "Configurazione Starship già esistente"
fi

# Aggiungi alias utili
log_step "Configurazione alias utili..."

ALIASES="
# Alias Docker
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dexec='docker exec -it'
alias dlogs='docker logs -f'
alias dprune='docker system prune -af'

# Alias sistema
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias search='pacman -Ss'
alias cleanup='sudo pacman -Sc'
"

# Aggiungi alias a .bashrc
if [ -f ~/.bashrc ]; then
    if ! grep -q "# Alias Docker" ~/.bashrc; then
        echo "$ALIASES" >> ~/.bashrc
        log_success "Alias aggiunti a .bashrc"
    else
        log_info "Alias già presenti in .bashrc"
    fi
fi

# Aggiungi alias a .zshrc se esiste
if [ -f ~/.zshrc ]; then
    if ! grep -q "# Alias Docker" ~/.zshrc; then
        echo "$ALIASES" >> ~/.zshrc
        log_success "Alias aggiunti a .zshrc"
    else
        log_info "Alias già presenti in .zshrc"
    fi
fi

log_success "Ambiente di sviluppo configurato"
log_info "Per applicare le modifiche, esegui: source ~/.bashrc (o ~/.zshrc)"

print_separator "SETUP AMBIENTE COMPLETATO"
