# HWOS Integration for Hacker Shell
# Загружается при старте оболочки

# Автодополнение для hwins
_hwins() {
  local cur prev words cword
  _init_completion || return
  local commands="install remove update upgrade sync search info list files clean orphans check help version"
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
  elif [[ $cword -ge 2 ]]; then
    case "${words[1]}" in
      install|-S|remove|-R|info|-Si|search|-Ss)
        COMPREPLY=($(compgen -W "$(pacman -Ssq "$cur" 2>/dev/null)" -- "$cur")) ;;
    esac
  fi
}
complete -F _hwins hwins

# История
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T "

shopt -s histappend checkwinsize no_empty_cmd_completion autocd dirspell cdspell 2>/dev/null || true

bind '"\e[A": history-search-backward' 2>/dev/null || true
bind '"\e[B": history-search-forward' 2>/dev/null || true

# Русский helper
ru() {
  cat << 'RU'
HWOS поддерживает русский язык везде:
  • hwos-help    — справка на русском
  • hwos-welcome — приветствие
  • hwins        — менеджер пакетов на русском
  • hwos-update  — обновление по-русски
  • hwos-firewall, hwos-encrypt — тоже!

Чтобы всё было на русском, HWOS уже настроен.
Просто пользуйтесь! 🚀
RU
}

# Приветствие при первом запуске
if [[ -z "${HWOS_WELCOMED:-}" ]]; then
  export HWOS_WELCOMED=1
  [[ -f /usr/bin/hwos-welcome ]] && [[ ! -f "$HOME/.hacker_initialized" ]] && {
    hwos-welcome 2>/dev/null || true
    touch "$HOME/.hacker_initialized"
  }
fi
