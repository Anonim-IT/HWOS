# Hacker Shell

Hacker Shell — собственная оболочка HWOS. Русский промпт, автодополнение, HWOS-команды.

## Запуск

```bash
hacker              # Интерактивная оболочка
hacker --help       # Справка
hacker --version    # Версия
```

По умолчанию Hacker Shell установлена как оболочка входа.

## Промпт

```
╭─user@hwos 14:30 ~ SPb
╰─ $
```

- `user@hwos` — пользователь@хост зелёным/голубым
- `14:30` — текущее время
- `~` — текущая директория
- `SPb` — отметка Санкт-Петербурга
- `$` — приглашение (меняется на `#` для root)
- При ошибке: `[✗ код]` красным

## Алиасы

| Алиас | Команда |
|-------|---------|
| `hwfetch` | `fastfetch -c /etc/fastfetch/config.jsonc` |
| `hwupdate` | `hwos-update all` |
| `hwfw` | `hwos-firewall` |
| `hwencrypt` | `hwos-encrypt` |
| `hwinstall` | `sudo hwos-installer` |
| `hwhelp` | `hwos-help` |
| `hwelcome` | `hwos-welcome` |
| `hwregion` | `sudo hwos-region` |
| `ll` | `ls -lah` |
| `c` | `clear` |
| `..` | `cd ..` |

## Автодополнение

Hacker Shell поддерживает автодополнение для `hwins`:

```bash
hwins in<TAB> → hwins install
hwins install fi<TAB> → hwins install firefox
```

## История

- `HISTSIZE=10000` — 10 000 команд в истории
- `HISTTIMEFORMAT` — с датой и временем
- Поиск по стрелкам вверх/вниз

## Кастомизация

Создайте `~/.hackerrc` для своих настроек:

```bash
# Пример .hackerrc
export EDITOR=nvim
alias myip='curl -s ifconfig.me'

# Своя функция
hw() {
    echo "Привет из HWOS!"
}
```

## При первом входе

При первом запуске показывается приветствие `hwos-welcome`:
- Список команд
- Полезные советы
- Информация о регионе
