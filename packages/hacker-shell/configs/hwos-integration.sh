# HWOS Integration for Hacker Shell
# This file is sourced by the Hacker Shell on startup

# HWOS completion
_hwins() {
    local cur prev words cword
    _init_completion || return

    local commands="install remove update upgrade sync search info list files clean orphans check help version"

    if [[ $cword -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    elif [[ $cword -ge 2 ]]; then
        case "${words[1]}" in
            install|-S|remove|-R|info|-Si|search|-Ss)
                COMPREPLY=($(compgen -W "$(pacman -Ssq "$cur" 2>/dev/null)" -- "$cur"))
                ;;
        esac
    fi
}

complete -F _hwins hwins

# Custom keybindings
bind '"\e[A": history-search-backward' 2>/dev/null || true
bind '"\e[B": history-search-forward' 2>/dev/null || true
bind '"\e[5~": beginning-of-history' 2>/dev/null || true
bind '"\e[6~": end-of-history' 2>/dev/null || true

# History settings
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T "

# shopt
shopt -s histappend 2>/dev/null || true
shopt -s checkwinsize 2>/dev/null || true
shopt -s no_empty_cmd_completion 2>/dev/null || true
shopt -s autocd 2>/dev/null || true
shopt -s dirspell 2>/dev/null || true
shopt -s cdspell 2>/dev/null || true

# HWOS banner function
hw-banner() {
    fastfetch -c /etc/fastfetch/config.jsonc
}

# System info shortcut
hw-fetch() {
    fastfetch -c /etc/fastfetch/config.jsonc "$@"
}
