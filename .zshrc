# Created by newuser for 5.8
# zsh: дедуп PATH (и stop разрастания дублей)
typeset -U path PATH

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
alias gpsh='f() { if [ -z "$1" ]; then echo "Ошибка: укажите сообщение коммита"; else git add . && git commit -m "$1" && git push; fi }; f'
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
alias ll='ls -la'
alias ..='cd ..'
alias cls='clear'

# Windows/Cygwin specific settings
if [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]]; then
    alias w='zed Z:/dev/work/new.editor.mir.1t.ru/src/player'

    CYGWIN_PATH=$(echo $PATH | tr ':' '\n' | grep -v "^/usr/bin$" | tr '\n' ':')
    export PATH="/c/Program Files/Git/mingw64/bin:$PATH"

    # Универсальная функция перехода на диск
    # Использование: c, d, z, e
    to_drive() {
        if [ -d "/$1" ]; then
            cd /$1
        elif [ -d "/cygdrive/$1" ]; then
            cd /cygdrive/$1
        else
            echo "Диск $1 не найден"
        fi
    }

    # Создаем короткие команды
    alias c='to_drive c'
    alias z='to_drive z'
fi
