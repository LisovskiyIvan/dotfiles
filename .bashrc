# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Git aliases
alias gb='git branch'
alias gp='git pull'
alias gco='git checkout'
alias gc='git commit -m'
alias gst='git stash'
alias gstp='git stash pop'
alias gm='git merge'
alias ga='git add .'
alias g='git'
alias gpsh='f() { if [ -z "$1" ]; then echo "Ошибка: укажите сообщение коммита"; else git add . && git commit -m "$1" && git push; fi }; f'
alias gl='git log --oneline --graph --decorate --all'

# History de-dup and sync
HISTCONTROL=ignoredups:erasedups
shopt -s histappend
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a; history -n"

alias v='nvim'
alias vn='neovide --fork'
alias a='helix'
alias ll='ls -la'
alias ..='cd ..'
alias cls='clear'
alias zed='zeditor'
alias wu='nmcli connection up client'
alias wd='nmcli connection down client'
alias cr='cargo run'
alias cbr='cargo build release'

. "$HOME/.local/share/../bin/env"
export PATH="/home/dayme/.cache/.bun/bin:$PATH"
# opencode
export PATH=/home/dayme/.opencode/bin:$PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"
. "$HOME/.cargo/env"

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
# <<< grok installer <<<

# mimocode
export PATH=/home/dayme/.mimocode/bin:$PATH
