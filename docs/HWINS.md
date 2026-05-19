# hwins — Менеджер пакетов HWOS

`hwins` — это собственный менеджер пакетов HWOS, обёртка над `pacman` с русским интерфейсом.

## Использование

```bash
hwins install пакет     # Установить программу
hwins remove пакет      # Удалить программу
hwins search запрос     # Найти программу
hwins update            # Обновить базу пакетов
hwins upgrade           # Обновить все программы
hwins sync              # Полное обновление системы
hwins list              # Список установленных пакетов
hwins info пакет        # Информация о пакете
hwins files пакет       # Файлы пакета
hwins clean             # Очистить кэш
hwins orphans           # Найти осиротевшие пакеты
hwins check             # Проверить зависимости
```

## Примеры

```bash
# Установить браузер
hwins install firefox

# Найти игру
hwins search game

# Полностью обновить систему
hwins sync

# Посмотреть информацию о пакете
hwins info linux-hacker
```

## Чем hwins отличается от pacman

- Все сообщения на русском языке
- Упрощённый синтаксис (не нужно помнить `-S`, `-R` и т.д.)
- Цветной вывод
- Дружественные подсказки для новичков

## Технические детали

`hwins` — это bash-скрипт, который транслирует команды в соответствующие вызовы `pacman`:

| hwins | pacman |
|-------|--------|
| `hwins install` | `pacman -S` |
| `hwins remove` | `pacman -Rns` |
| `hwins search` | `pacman -Ss` |
| `hwins update` | `pacman -Sy` |
| `hwins upgrade` | `pacman -Su` |
| `hwins sync` | `pacman -Syu` |
| `hwins list` | `pacman -Q` |
| `hwins info` | `pacman -Qi` |
| `hwins files` | `pacman -Ql` |
| `hwins clean` | `pacman -Sc` |
| `hwins orphans` | `pacman -Qdt` |
| `hwins check` | `pacman -Qk` |
