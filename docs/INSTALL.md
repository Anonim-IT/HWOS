# Установка HWOS

## Системные требования

- Процессор: x86_64 (64-битный)
- ОЗУ: минимум 2 ГБ (рекомендуется 4+ ГБ)
- Диск: минимум 20 ГБ (рекомендуется 40+ ГБ)
- UEFI (рекомендуется) или BIOS

## Установка с Live ISO

### Шаг 1: Загрузка

1. Запишите HWOS ISO на флешку:
   ```bash
   sudo dd if=hwos.iso of=/dev/sdX bs=4M status=progress
   ```
2. Загрузитесь с флешки (выберите в BIOS/UEFI)
3. В меню GRUB выберите «Запустить HWOS» или «Установить HWOS на диск»

### Шаг 2: TUI-инсталер

После загрузки Live-системы запустится TUI-инсталер. Пройдите шаги:

1. **Выбор региона** — 🇷🇺 Россия или 🌍 Международный
2. **Язык установщика** — Русский / English
3. **Режим установки**:
   - **Для новичков** — автоматическая разметка диска (GPT + ESP + swap + root)
   - **Эксперт** — ручная разметка через cfdisk
4. **Выбор диска** — выберите целевой диск
5. **Пользователь** — имя, пароль, имя компьютера
6. **Подтверждение** — проверьте параметры и начните установку

### Шаг 3: Ожидание

Инсталер выполнит:
- Разметку и форматирование разделов
- Установку базовой системы (pacstrap)
- Генерацию fstab
- Настройку локали, языка, раскладки
- Создание пользователя
- Установку и настройку GRUB (HackerRUB)
- Включение служб (NetworkManager)

### Шаг 4: Перезагрузка

После завершения установки перезагрузитесь и войдите в HWOS.

## Ручная установка (для экспертов)

Если TUI-инсталер не подходит, можно установить HWOS вручную:

```bash
# 1. Разметка диска
parted /dev/sdX mklabel gpt
parted /dev/sdX mkpart primary fat32 1MiB 512MiB
parted /dev/sdX set 1 esp on
parted /dev/sdX mkpart primary linux-swap 512MiB 4GiB
parted /dev/sdX mkpart primary 4GiB 100%

# 2. Форматирование
mkfs.fat -F32 /dev/sdX1
mkswap /dev/sdX2
mkfs.ext4 /dev/sdX3

# 3. Монтирование
mount /dev/sdX3 /mnt
mkdir -p /mnt/boot
mount /dev/sdX1 /mnt/boot
swapon /dev/sdX2

# 4. Установка пакетов
pacstrap -K /mnt base base-devel linux-hacker linux-hacker-headers \
  linux-firmware grub efibootmgr networkmanager nano vim sudo \
  hwins hackerrub hwos-scripts hwos-configs hwos-theme

# 5. Настройка
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash << 'CHROOT'
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf
echo "KEYMAP=ru" > /etc/vconsole.conf
echo "FONT=cyr-sun16" >> /etc/vconsole.conf
locale-gen
echo "hwos" > /etc/hostname
useradd -m -G wheel -s /bin/bash user
echo "user:password" | chpasswd
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=HackerRUB
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager
CHROOT

# 6. Перезагрузка
umount -R /mnt
reboot
```

## Установка поверх существующей системы Arch

Если у вас уже установлен Arch Linux, установите HWOS поверх:

```bash
# Подключите репозиторий HWOS
echo "[hwos]" >> /etc/pacman.conf
echo "SigLevel = Optional TrustAll" >> /etc/pacman.conf
echo "Server = https://hwos.dev/repo/x86_64" >> /etc/pacman.conf

# Установите компоненты HWOS
pacman -Syyu
pacman -S linux-hacker linux-hacker-headers hwins hwos-scripts \
  hwos-configs hwos-theme hacker-shell hackerrub hwos-installer

# Установите Hacker Shell как оболочку по умолчанию
chsh -s /usr/bin/hacker

# Настройте регион
hwos-region ru
```
