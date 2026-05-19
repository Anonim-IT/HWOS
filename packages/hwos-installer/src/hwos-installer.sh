#!/usr/bin/env bash
# hwos-installer — Установщик Hacker Web OS
# Дружелюбный интерфейс для новичков на dialog
# Версия: 1.0.0

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'
VERSION="1.0.0"

L_() {
  case "$LANG" in
    ru|ru_RU*) echo "$1" ;;
    *) echo "${2:-$1}" ;;
  esac
}

check_root() { [[ $EUID -eq 0 ]] || exec sudo "$0" "$@"; }

check_deps() {
  for dep in dialog parted mkfs.ext4 mkfs.btrfs cryptsetup arch-chroot; do
    command -v "$dep" &>/dev/null || {
      echo -e "${RED}[!] Не найдена утилита: $dep${NC}"
      echo -e "${YELLOW}[*] Установи: sudo pacman -S dialog parted btrfs-progs cryptsetup arch-install-scripts${NC}"
      exit 1
    }
  done
}

show_logo() {
  dialog --colors --title "HWOS Installer v$VERSION" \
    --msgbox "\n\n\
    ██╗  ██╗██╗    ██╗ ██████╗ ███████╗\n\
    ██║  ██║██║    ██║██╔═══██╗██╔════╝\n\
    ███████║██║ █╗ ██║██║   ██║███████╗\n\
    ██╔══██║██║███╗██║██║   ██║╚════██║\n\
    ██║  ██║╚███╔███╔╝╚██████╔╝███████║\n\
    ╚═╝  ╚═╝ ╚══╝╚══╝  ╚═════╝ ╚══════╝\n\n\
    $($(L_ "ДОБРО ПОЖАЛОВАТЬ В HWOS!" "WELCOME TO HWOS!"))\n\
    $($(L_ "Hacker Web OS — простая и понятная система" "Hacker Web OS — simple and friendly"))\n\
    $($(L_ "Нажмите OK, чтобы начать установку" "Press OK to begin installation"))\n\n\
    $($(L_ "Совет: для установки используйте стрелки, Tab и Enter" "Tip: use arrows, Tab and Enter to navigate"))" 17 56
}

select_language() {
  LANG=$(dialog --clear --stdout \
    --title "$($(L_ "Язык системы" "System Language"))" \
    --menu "$($(L_ "Выберите язык установки:" "Select installation language:"))" \
    10 45 2 \
    "ru_RU.UTF-8" "🇷🇺 Русский — рекомендуется" \
    "en_US.UTF-8" "🇬🇧 English")
  export LANG
}

select_mode() {
  MODE=$(dialog --clear --stdout \
    --title "$($(L_ "Режим установки" "Installation Mode"))" \
    --menu "$($(L_ "Выберите режим:" "Select mode:"))" \
    12 55 2 \
    "easy" "🌱 $(L_ "Для новичков — всё настроится само" "For beginners — automatic setup")" \
    "expert" "🧑‍💻 $(L_ "Эксперт — ручная настройка каждого шага" "Expert — manual step-by-step")")
  export MODE
}

select_disk() {
  local disks=()
  while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $4}')
    size=$(echo "$line" | awk '{print $3}')
    model=$(echo "$line" | cut -d' ' -f5-)
    [[ -z "$name" || "$name" == "loop"* ]] && continue
    disks+=("$name" "$model ($size)")
  done < <(lsblk -d -o NAME,SIZE,TYPE,MODEL -n -p 2>/dev/null)

  [[ ${#disks[@]} -eq 0 ]] && {
    dialog --title "$($(L_ "Ошибка" "Error"))" \
      --msgbox "$($(L_ "Не найден ни один диск!" "No disks found!"))" 5 40
    exit 1
  }

  DISK=$(dialog --clear --stdout \
    --title "$($(L_ "Выбор диска" "Disk Selection"))" \
    --menu "$($(L_ "Выберите диск для установки (ВСЕ ДАННЫЕ БУДУТ УДАЛЕНЫ):" "Select target disk (ALL DATA WILL BE WIPED):"))" \
    15 60 5 "${disks[@]}")
  export DISK
}

auto_partition() {
  dialog --title "$($(L_ "Авторазметка" "Auto Partition"))" \
    --infobox "$($(L_ "Выполняется автоматическая разметка диска... Это займёт несколько секунд." "Automatic partitioning in progress... This will take a few seconds."))" 5 50
  sleep 1

  parted -s "$DISK" mklabel gpt 2>/dev/null
  parted -s "$DISK" mkpart primary fat32 1MiB 512MiB 2>/dev/null
  parted -s "$DISK" set 1 esp on 2>/dev/null
  SWAP_SIZE=$(free -m | awk '/^Mem:/{print int($2/2)}')
  SWAP_END=$(( SWAP_SIZE + 4096 ))
  parted -s "$DISK" mkpart primary linux-swap 512MiB "${SWAP_END}MiB" 2>/dev/null
  parted -s "$DISK" mkpart primary "${SWAP_END}MiB" 100% 2>/dev/null
  sleep 1
}

manual_partition() {
  dialog --title "$($(L_ "Ручная разметка" "Manual Partitioning"))" \
    --msgbox "$($(L_ "Сейчас будет открыт cfdisk — стандартный редактор разделов Linux.
Создайте минимум 3 раздела:
  • ESP (fat32, 512МБ, флаг boot)
  • swap (linux-swap, 2-4ГБ)
  • корневой (ext4/btrfs/xfs, весь оставшийся объём)

После завершения закройте cfdisk." "cfdisk will open — the standard Linux partition editor.
Create at least 3 partitions:
  • ESP (fat32, 512MB, boot flag)
  • swap (linux-swap, 2-4GB)
  • root (ext4/btrfs/xfs, remaining space)

Close cfdisk when done."))" 16 60
  cfdisk "$DISK"
}

select_partitions() {
  if [[ "$MODE" == "easy" ]]; then
    auto_partition
    PART_BOOT="${DISK}1"
    PART_SWAP="${DISK}2"
    PART_ROOT="${DISK}3"
  else
    manual_partition
    local parts=()
    while IFS= read -r line; do
      name=$(echo "$line" | awk '{print $4}')
      size=$(echo "$line" | awk '{print $3}')
      fstype=$(echo "$line" | awk '{print $5}')
      parts+=("$name" "$fstype ($size)")
    done < <(lsblk -o NAME,SIZE,FSTYPE -n -p "$DISK" 2>/dev/null | tail -n +2)

    PART_BOOT=$(dialog --clear --stdout \
      --title "$($(L_ "Выберите EFI раздел" "Select EFI partition"))" \
      --menu "$($(L_ "Выберите раздел для /boot (ESP, fat32):" "Select partition for /boot (ESP, fat32):"))" \
      12 50 3 "${parts[@]}")

    PART_SWAP=$(dialog --clear --stdout \
      --title "$($(L_ "Выберите swap раздел" "Select swap partition"))" \
      --menu "$($(L_ "Выберите раздел для swap:" "Select swap partition:"))" \
      12 50 3 "${parts[@]}")

    PART_ROOT=$(dialog --clear --stdout \
      --title "$($(L_ "Выберите корневой раздел" "Select root partition"))" \
      --menu "$($(L_ "Выберите раздел для системы (/):" "Select root partition (/) :"))" \
      12 50 3 "${parts[@]}")
  fi
  export PART_BOOT PART_SWAP PART_ROOT
}

select_filesystem() {
  FSTYPE=$(dialog --clear --stdout \
    --title "$($(L_ "Файловая система" "Filesystem"))" \
    --menu "$($(L_ "Выберите тип файловой системы:" "Select filesystem type:"))" \
    11 50 3 \
    "btrfs" "BTRFS $(L_ "(рекомендуется, снимки)" "(recommended, snapshots)")" \
    "ext4" "Ext4 $(L_ "(классическая, надёжная)" "(classic, reliable)")")
  export FSTYPE
}

select_encryption() {
  dialog --title "$($(L_ "Шифрование" "Encryption"))" \
    --yesno "$($(L_ "Включить шифрование диска (LUKS)?
Это защитит ваши данные паролем при загрузке.
Рекомендуется для ноутбуков." "Enable full disk encryption (LUKS)?
This will protect your data with a password at boot.
Recommended for laptops."))" 9 55
  ENCRYPT=$([ $? -eq 0 ] && echo "yes" || echo "no")
  export ENCRYPT
  if [[ "$ENCRYPT" == "yes" ]]; then
    PASS1=$(dialog --clear --stdout \
      --title "$($(L_ "Пароль шифрования" "Encryption Password"))" \
      --insecure --passwordbox "$($(L_ "Придумайте пароль для шифрования диска:" "Create a disk encryption password:"))" 8 50)
    PASS2=$(dialog --clear --stdout \
      --title "$($(L_ "Подтверждение" "Confirm Password"))" \
      --insecure --passwordbox "$($(L_ "Повторите пароль:" "Repeat password:"))" 8 50)
    [[ "$PASS1" != "$PASS2" ]] && {
      dialog --title "$($(L_ "Ошибка" "Error"))" \
        --msgbox "$($(L_ "Пароли не совпадают! Попробуйте снова." "Passwords do not match! Try again."))" 5 45
      select_encryption; return
    }
    LUKS_PASS="$PASS1"
    export LUKS_PASS
  fi
}

select_hostname() {
  HOSTNAME=$(dialog --clear --stdout \
    --title "$($(L_ "Имя компьютера" "Hostname"))" \
    --inputbox "$($(L_ "Введите имя компьютера (как он будет называться в сети):" "Enter computer name (hostname):"))" \
    8 55 "hwos-pc")
  HOSTNAME=${HOSTNAME:-hwos-pc}
  export HOSTNAME
}

create_user() {
  USERNAME=$(dialog --clear --stdout \
    --title "$($(L_ "Пользователь" "User Account"))" \
    --inputbox "$($(L_ "Придумайте имя пользователя (латиницей):" "Enter username (latin letters):"))" \
    8 55 "user")
  USERNAME=${USERNAME:-user}

  PASS1=$(dialog --clear --stdout \
    --title "$($(L_ "Пароль пользователя" "User Password"))" \
    --insecure --passwordbox "$($(L_ "Придумайте пароль для" "Create password for")) $USERNAME:" 8 50)
  PASS2=$(dialog --clear --stdout \
    --title "$($(L_ "Подтверждение" "Confirm Password"))" \
    --insecure --passwordbox "$($(L_ "Повторите пароль:" "Repeat password:"))" 8 50)
  [[ "$PASS1" != "$PASS2" ]] && {
    dialog --title "$($(L_ "Ошибка" "Error"))" --msgbox "$($(L_ "Пароли не совпадают!" "Passwords do not match!"))" 5 40
    create_user; return
  }
  USER_PASS="$PASS1"
  export USERNAME USER_PASS
}

select_wm() {
  WM=$(dialog --clear --stdout \
    --title "$($(L_ "Рабочее окружение" "Window Manager"))" \
    --menu "$($(L_ "Выберите удобное для вас окружение:" "Select your preferred environment:"))" \
    14 55 4 \
    "hyprland" "🖥️ Hyprland $(L_ "(красивый, современный)" "(beautiful, modern)")" \
    "sway" "🖥️ Sway $(L_ "(простой, как i3)" "(simple, like i3)")" \
    "i3" "🖥️ i3 $(L_ "(классический тайлинг)" "(classic tiling)")" \
    "none" "📟 $(L_ "Только консоль (без графики)" "CLI only (no graphics)"))")
  export WM
}

select_timezone() {
  TZONE=$(dialog --clear --stdout \
    --title "$($(L_ "Часовой пояс" "Timezone"))" \
    --menu "$($(L_ "Выберите ваш часовой пояс:" "Select your timezone:"))" \
    12 45 4 \
    "Europe/Moscow" "🇷🇺 Москва (MSK)" \
    "Europe/Kaliningrad" "🇷🇺 Калининград" \
    "Asia/Yekaterinburg" "🇷🇺 Екатеринбург" \
    "UTC" "🌐 UTC")
  TZONE=${TZONE:-Europe/Moscow}
  export TZONE
}

install_system() {
  (
  echo "5"
  echo "XXX"; echo "$($(L_ "Подготовка разделов..." "Preparing partitions..."))"; echo "XXX"

  # Format
  mkfs.fat -F32 "$PART_BOOT" 2>/dev/null
  mkswap "$PART_SWAP" 2>/dev/null
  swapon "$PART_SWAP" 2>/dev/null

  if [[ "$ENCRYPT" == "yes" ]]; then
    echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks2 "$PART_ROOT" 2>/dev/null
    echo -n "$LUKS_PASS" | cryptsetup open "$PART_ROOT" hwos_root 2>/dev/null
    ROOT_DEV="/dev/mapper/hwos_root"
  else
    ROOT_DEV="$PART_ROOT"
  fi

  echo "15"
  echo "XXX"; echo "$($(L_ "Форматирование..." "Formatting..."))"; echo "XXX"

  case "$FSTYPE" in
    btrfs)
      mkfs.btrfs -f "$ROOT_DEV" 2>/dev/null
      mount "$ROOT_DEV" /mnt
      btrfs subvolume create /mnt/@ 2>/dev/null
      btrfs subvolume create /mnt/@home 2>/dev/null
      btrfs subvolume create /mnt/@snapshots 2>/dev/null
      umount /mnt
      mount -o compress=zstd,subvol=@ "$ROOT_DEV" /mnt
      mkdir -p /mnt/{home,.snapshots,boot}
      mount -o compress=zstd,subvol=@home "$ROOT_DEV" /mnt/home
      mount -o compress=zstd,subvol=@snapshots "$ROOT_DEV" /mnt/.snapshots
      ;;
    ext4)
      mkfs.ext4 -F "$ROOT_DEV" 2>/dev/null
      mount "$ROOT_DEV" /mnt
      mkdir -p /mnt/boot
      ;;
  esac

  mount "$PART_BOOT" /mnt/boot

  echo "30"
  echo "XXX"; echo "$($(L_ "Установка системы... (может занять 5-10 минут)" "Installing system... (5-10 minutes)"))"; echo "XXX"

  pacstrap -K /mnt base base-devel linux linux-firmware \
    amd-ucode intel-ucode \
    grub efibootmgr networkmanager iwd \
    "$WM" sddm pipewire pipewire-pulse wireplumber \
    nftables fastfetch zsh git \
    hwins hwos-scripts hwos-configs hwos-theme hwos-installer hacker-shell 2>/dev/null

  echo "60"
  echo "XXX"; echo "$($(L_ "Настройка системы..." "Configuring system..."))"; echo "XXX"

  genfstab -U /mnt >> /mnt/etc/fstab

  arch-chroot /mnt /bin/bash <<CHROOT
ln -sf "/usr/share/zoneinfo/$TZONE" /etc/localtime
hwclock --systohc

sed -i 's/^#ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

echo "LANG=ru_RU.UTF-8" > /etc/locale.conf
echo "KEYMAP=ru" > /etc/vconsole.conf
echo "FONT=cyr-sun16" >> /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

systemctl enable NetworkManager
systemctl enable iwd
systemctl enable sddm
systemctl enable bluetooth
systemctl enable fstrim.timer

echo "root:$USER_PASS" | chpasswd
useradd -m -G wheel,audio,video,network,storage -s /usr/bin/hacker "$USERNAME" 2>/dev/null
echo "$USERNAME:$USER_PASS" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=HackerRUB 2>/dev/null
grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null

hwos-setup-fastfetch 2>/dev/null
CHROOT

  echo "90"
  echo "XXX"; echo "$($(L_ "Завершение..." "Finalizing..."))"; echo "XXX"

  umount -R /mnt 2>/dev/null || true

  echo "100"
  echo "XXX"; echo "$($(L_ "Установка завершена!" "Installation complete!"))"; echo "XXX"
  ) | dialog --title "$($(L_ "Установка HWOS" "Installing HWOS"))" \
    --gauge "$($(L_ "Подготовка..." "Preparing..."))" 8 60 0
}

summary() {
  local enc_str=$([ "$ENCRYPT" == "yes" ] && \
    echo "$($(L_ "Да (LUKS)" "Yes (LUKS)"))" || \
    echo "$($(L_ "Нет" "No"))")
  dialog --title "$($(L_ "Установка завершена!" "Installation Complete!"))" \
    --msgbox "$($(L_ "\
    УСТАНОВКА HWOS ЗАВЕРШЕНА!\n\n\
    Диск: $DISK\n\
    Файловая система: $FSTYPE\n\
    Шифрование: $enc_str\n\
    Окружение: $WM\n\
    Пользователь: $USERNAME\n\
    Часовой пояс: $TZONE\n\n\
    После перезагрузки вас встретит:\n\
    • Русскоязычный интерфейс\n\
    • Готовый к работе Hyprland/i3/Sway\n\
    • Hacker Shell — удобная оболочка\n\
    • Все драйверы и кодеки" "\
    HWOS INSTALLATION COMPLETE!\n\n\
    Disk: $DISK\n\
    Filesystem: $FSTYPE\n\
    Encryption: $enc_str\n\
    WM: $WM\n\
    User: $USERNAME\n\
    Timezone: $TZONE\n\n\
    After reboot you will get:\n\
    • Russian interface\n\
    • Ready-to-use Hyprland/i3/Sway\n\
    • Hacker Shell\n\
    • All drivers and codecs"))" 20 60
}

main() {
  check_root
  check_deps

  show_logo
  select_language
  select_mode

  dialog --title "$($(L_ "Подготовка" "Preparation"))" \
    --yesno "$($(L_ "Перед установкой убедитесь, что вы:\n\
  1. Подключены к интернету\n\
  2. Сделали бэкап важных данных\n\
  3. Зарядили ноутбук от сети (если это ноутбук)\n\n\
Продолжить установку?" "Before installation, make sure:\n\
  1. You are connected to the internet\n\
  2. You backed up your important data\n\
  3. Your laptop is plugged in (if laptop)\n\n\
Continue installation?"))" 12 55 || exit 1

  select_disk
  select_partitions
  select_filesystem
  select_encryption
  select_hostname
  create_user
  select_wm
  select_timezone

  dialog --title "$($(L_ "Подтверждение" "Confirmation"))" \
    --yesno "$($(L_ "Готовы к установке HWOS на $DISK?\n\n\
ВСЕ ДАННЫЕ НА ДИСКЕ БУДУТ УДАЛЕНЫ!" "Ready to install HWOS on $DISK?\n\n\
ALL DATA ON THIS DISK WILL BE WIPED!"))" 8 55
  case $? in
    0) install_system ;;
    1) dialog --title "$($(L_ "Отмена" "Cancelled"))" \
      --msgbox "$($(L_ "Установка отменена." "Installation cancelled."))" 5 45; exit 1 ;;
  esac

  summary
  dialog --title "$($(L_ "Перезагрузка" "Reboot"))" \
    --yesno "$($(L_ "Перезагрузить компьютер сейчас?" "Reboot now?"))" 5 40
  [[ $? -eq 0 ]] && reboot
}

main "$@"
