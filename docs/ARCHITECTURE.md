# Архитектура HWOS

## Обзор

HWOS базируется на Arch Linux и использует стандартные компоненты Arch с собственными обёртками и темами.

```
┌─────────────────────────────────────────┐
│           Hacker Shell                  │
│    /usr/bin/hacker (bash/zsh)           │
├─────────────────────────────────────────┤
│  hwins    │  hwos-*    │  hwfetch      │
│  (pacman) │  (утилиты) │  (fastfetch)  │
├───────────┴────────────┴───────────────┤
│         Hacker-Kernel (linux-hacker)    │
│       Linux 6.1 LTS + hardening         │
├─────────────────────────────────────────┤
│  HackerRUB (GRUB theme + bootloader)   │
│       Цвета российского флага           │
├─────────────────────────────────────────┤
│     Arch Linux (base, systemd, glibc)   │
└─────────────────────────────────────────┘
```

## Компоненты

### 1. Hacker-Kernel (`linux-hacker`)

- Ядро Linux 6.1 LTS с патчами безопасности
- Кастомная конфигурация (убрано лишнее, включена защита)
- Поддержка Spectre/Meltdown mitigation
- Имя пакета: `linux-hacker`
- Выходной образ: `vmlinuz-linux-hacker`

### 2. hwins — менеджер пакетов

- Обёртка bash вокруг pacman
- Русскоязычный интерфейс
- Простой синтаксис: `hwins install firefox`

### 3. TUI-инсталер (`hwos-installer`)

- Написан на Python (curses, stdlib)
- Режимы: «Для новичков» (авто) / «Эксперт» (ручной)
- Поддержка двух регионов
- Установка HackerRUB GRUB

### 4. Hacker Shell (`hacker`)

- Оболочка на bash/ZSH
- Цветной промпт с временем и SPb
- Алиасы для всех HWOS-команд
- Автодополнение для hwins

### 5. HackerRUB (GRUB)

- Кастомная тема GRUB в цветах флага РФ
- Автоматическая установка при инстале
- Настройки в `/etc/default/grub`

### 6. Системные утилиты (`hwos-*`)

| Утилита | Описание |
|---------|----------|
| `hwos-update` | Обновление системы |
| `hwos-firewall` | Фаервол (nftables) |
| `hwos-encrypt` | Шифрование (LUKS) |
| `hwos-region` | Переключение региона |
| `hwos-help` | Справка |
| `hwos-welcome` | Приветствие при входе |

### 7. Конфиги (`hwos-configs`)

- `/etc/hwos-release` — информация о системе
- `/etc/os-release` — стандартный os-release
- `/etc/motd` — сообщение дня
- `/etc/sysctl.d/99-hwos-hardening.conf` — закалка ядра
- `/etc/systemd/journald.conf.d/00-hwos.conf` — настройки журнала

### 8. Тема fastfetch (`hwos-theme`)

- Цветовая схема: белый/синий/красный (триколор)
- Отображение: ОС, ядро, пакеты, оболочка, WM, память, диск, IP
- Футер: «Сделано в Санкт-Петербурге ❤️»

## Сборка

### Сборка пакетов

```bash
./custom-repo/hwos-repo-build-all.sh
```

### Сборка ISO

```bash
./scripts/build-iso.sh
```

## Структура директорий пакетов

```
packages/<имя>/
├── PKGBUILD          # Arch Linux PKGBUILD
├── <имя>.install     # post-install скрипт (опционально)
└── src/              # исходники (опционально)
```
