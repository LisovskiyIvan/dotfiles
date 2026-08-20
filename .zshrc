# Created by newuser for 5.8
# zsh: дедуп PATH (и stop разрастания дублей)
typeset -U path PATH

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# bun
export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && path=("$BUN_INSTALL/bin" $path)

alias gb='git branch'
alias gp='git pull'
alias gco='git checkout'
alias gc='git commit -m'
alias gst='git stash'
alias gstp='git stash pop'
alias gm='git merge'
alias ga='git add .'
alias g='git'
alias gl="git log --oneline --graph --decorate --all"

# Убрать дубликаты из истории
setopt HIST_IGNORE_DUPS
setopt CORRECT
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
# Сохранять историю сразу
setopt SHARE_HISTORY
alias v='nvim'
alias vn='neovide'
alias c='opencode'
alias ll='ls -la'
alias ..='cd ..'
alias cls='clear'

# Load opencode secrets
if [ -f "$HOME/dev/myself/dotfiles/opencode/.env" ]; then
    export $(grep -v '^#' "$HOME/dev/myself/dotfiles/opencode/.env" | xargs)
fi

# zoxide — замена cd (z / zi тоже работают)
eval "$(zoxide init zsh --cmd cd)"

# eza — замена ls с иконками и цветами
alias ls='eza --icons --color=auto --group-directories-first'
alias ll='eza -la --icons --color=auto --group-directories-first --git'
alias lt='eza -T --icons --color=auto --group-directories-first'
alias tree='eza -T --icons'

# bun completions
[ -s "/Users/ivan/.bun/_bun" ] && source "/Users/ivan/.bun/_bun"
