#!/usr/bin/env bash
# hwos-installer — Установщик HWOS
set -euo pipefail

export DIALOGOPTS="--colors --backtitle 'HWOS Installer v1.0.0 — Сделано в Санкт-Петербурге'"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

# ============================================================
# LANGUAGE HELPER
# ============================================================
L_() {
  if [[ "${LANG:-ru_RU.UTF-8}" == ru* ]]; then
    echo "$1"
  else
    echo "${2:-$1}"
  fi
}

# ============================================================
# GLOBALS
# ============================================================
DISK=""
USERNAME=""
PASSWORD=""
HOSTNAME="hwos"
REGION="ru"

# ============================================================
# UTILITY
# ============================================================
check_root() { [[ $EUID -eq 0 ]] || exec sudo "$0" "$@"; }

cleanup() {
  rm -f /tmp/hwos_install_*.txt
}

# ============================================================
# REGION SELECTION
# ============================================================
select_region() {
  exec 3>&1
  local choice=$(dialog --title "$($(L_ "Выбор региона" "Region Selection"))" \
    --menu "$($(L_ "Выберите регион установки:" "Choose installation region:"))" \
    12 50 2 \
    "ru"  "$($(L_ "🇷🇺 Россия — русский язык, Яндекс-зеркала" "🇷🇺 Russia — Russian language, Yandex mirrors"))" \
    "int" "$($(L_ "🌍 Международный — английский язык, глобальные зеркала" "🌍 International — English, global mirrors"))" \
    2>&1 1>&3)
  local ret=$?
  exec 3>&-
  if [[ $ret -eq 0 ]]; then
    REGION="$choice"
  fi
}

# ============================================================
# LANGUAGE SELECTION
# ============================================================
select_language() {
  exec 3>&1
  local choice=$(dialog --title "$($(L_ "Выбор языка установки" "Installation Language"))" \
    --menu "$($(L_ "Выберите язык установщика:" "Choose the installer language:"))" \
    10 50 2 \
    "ru" "$($(L_ "Русский" "Russian"))" \
    "en" "$($(L_ "English" "English"))" \
    2>&1 1>&3)
  local ret=$?
  exec 3>&-
  if [[ $ret -eq 0 ]]; then
    if [[ "$choice" == "ru" ]]; then
      export LANG=ru_RU.UTF-8
    else
      export LANG=en_US.UTF-8
    fi
  fi
}

# ============================================================
# MODE SELECTION
# ============================================================
select_mode() {
  exec 3>&1
  local choice=$(dialog --title "$($(L_ "Режим установки" "Installation Mode"))" \
    --menu "$($(L_ "Выберите режим:" "Choose a mode:"))" \
    12 55 2 \
    "easy"   "$($(L_ "Для новичков — всё автоматически" "For beginners — everything is automatic"))" \
    "expert" "$($(L_ "Эксперт — ручная настройка разделов" "Expert — manual partitioning"))" \
    2>&1 1>&3)
  local ret=$?
  exec 3>&-
  if [[ $ret -eq 0 ]]; then
    MODE="$choice"
  else
    exit 1
  fi
}

# ============================================================
# DISK SELECTION
# ============================================================
select_disk() {
  local disks=$(lsblk -dno NAME,SIZE,MODEL | awk '{print "/dev/" $1, $2, $3}' | tr '\n' ' ')
  if [[ -z "$disks" ]]; then
    dialog --title "$($(L_ "Ошибка" "Error"))" \
      --msgbox "$($(L_ "Не найден ни один диск!" "No disks found!"))" 5 40
    exit 1
  fi
  exec 3>&1
  local choice=$(dialog --title "$($(L_ "Выбор диска" "Select Disk"))" \
    --menu "$($(L_ "Выберите диск для установки HWOS:" "Select a disk for HWOS installation:"))" \
    15 55 4 \
    $disks \
    2>&1 1>&3)
  local ret=$?
  exec 3>&-
  if [[ $ret -eq 0 ]]; then
    DISK="$choice"
  else
    exit 1
  fi
}

# ============================================================
# AUTO PARTITION
# ============================================================
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
  else
    manual_partition
  fi
}

# ============================================================
# DETECT PARTITIONS
# ============================================================
detect_partitions() {
  ESP=""
  SWAP=""
  ROOT=""
  local parts=$(lsblk -nlo NAME,TYPE,SIZE,FSTYPE "$DISK" | grep part)
  local part_name
  while IFS= read -r line; do
    part_name="/dev/$(echo $line | awk '{print $1}')"
    local fstype=$(echo $line | awk '{print $4}')
    local size=$(echo $line | awk '{print $3}')
    if echo "$line" | grep -qi "fat\|vfat\|esp" || [[ "$fstype" == "vfat" ]] || [[ "$fstype" == "fat32" ]]; then
      ESP="$part_name"
    elif [[ -z "$SWAP" ]] && (echo "$line" | grep -qi "swap" || [[ "$fstype" == "swap" ]]); then
      SWAP="$part_name"
    elif [[ -z "$ROOT" ]]; then
      ROOT="$part_name"
    fi
  done <<< "$parts"
  if [[ -z "$ESP" ]]; then
    ESP=$(lsblk -nlo NAME "$DISK" | head -2 | tail -1)
    ESP="/dev/$ESP"
  fi
  if [[ -z "$ROOT" ]]; then
    ROOT=$(lsblk -nlo NAME "$DISK" | tail -1)
    ROOT="/dev/$ROOT"
  fi
}

# ============================================================
# FORMAT PARTITIONS
# ============================================================
format_partitions() {
  dialog --title "$($(L_ "Форматирование" "Formatting"))" \
    --yesno "$($(L_ "Форматировать разделы?
  ESP:  $ESP
  ROOT: $ROOT

Все данные на этих разделах будут УНИЧТОЖЕНЫ!" "Format partitions?
  ESP:  $ESP
  ROOT: $ROOT

ALL data on these partitions will be DESTROYED!"))" 10 60
  [[ $? -ne 0 ]] && exit 1

  mkfs.fat -F32 "$ESP" 2>/dev/null
  mkfs.ext4 -F "$ROOT" 2>/dev/null

  if [[ -n "$SWAP" ]]; then
    mkswap "$SWAP" 2>/dev/null || true
  fi
}

# ============================================================
# MOUNT
# ============================================================
mount_partitions() {
  mount "$ROOT" /mnt
  mkdir -p /mnt/boot
  mount "$ESP" /mnt/boot
  if [[ -n "$SWAP" ]]; then
    swapon "$SWAP" 2>/dev/null || true
  fi
}

# ============================================================
# USER INPUT
# ============================================================
get_user_info() {
  exec 3>&1
  USERNAME=$(dialog --title "$($(L_ "Пользователь" "User Account"))" \
    --inputbox "$($(L_ "Введите имя пользователя:" "Enter username:"))" 8 50 "user" \
    2>&1 1>&3)
  local ret=$?
  exec 3>&-
  [[ $ret -ne 0 ]] && exit 1

  exec 3>&1
  PASSWORD=$(dialog --title "$($(L_ "Пользователь" "User Account"))" \
    --passwordbox "$($(L_ "Введите пароль:" "Enter password:"))" 8 50 \
    2>&1 1>&3)
  ret=$?
  exec 3>&-
  [[ $ret -ne 0 ]] && exit 1

  exec 3>&1
  HOSTNAME=$(dialog --title "$($(L_ "Имя компьютера" "Hostname"))" \
    --inputbox "$($(L_ "Введите имя компьютера:" "Enter hostname:"))" 8 50 "hwos" \
    2>&1 1>&3)
  ret=$?
  exec 3>&-
  [[ $ret -ne 0 ]] && HOSTNAME="hwos"
}

# ============================================================
# INSTALLATION
# ============================================================
run_pacstrap() {
  local packages="base base-devel linux-hacker linux-hacker-headers linux-firmware grub efibootmgr networkmanager dhcpcd nano vim sudo dialog hwins hackerrub hwos-scripts hwos-configs hwos-theme"


  if [[ "$REGION" == "ru" ]]; then
    packages="$packages ttf-liberation ttf-dejavu noto-fonts noto-fonts-emoji"
  fi

  dialog --title "$($(L_ "Установка" "Installation"))" \
    --infobox "$($(L_ "Установка HWOS в $ROOT... Это займёт некоторое время." "Installing HWOS to $ROOT... This will take a while."))" 5 50

  if [[ "$REGION" == "ru" ]]; then
    cat > /mnt/etc/pacman.d/mirrorlist << 'MIRRORS'
## HWOS — Российские зеркала
Server = https://mirror.yandex.ru/archlinux/$repo/os/$arch
Server = https://archlinux.mirror.colo-serv.net/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
MIRRORS
  else
    cat > /mnt/etc/pacman.d/mirrorlist << 'MIRRORS'
## HWOS — Международные зеркала
Server = https://archlinux.mirror.colo-serv.net/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
MIRRORS
  fi

  pacstrap -K /mnt $packages 2>&1 | dialog --title "$($(L_ "Установка" "Installation"))" \
    --progressbox "$($(L_ "Установка пакетов..." "Installing packages..."))" 20 70

  return ${PIPESTATUS[0]}
}

configure_system() {
  genfstab -U /mnt >> /mnt/etc/fstab

  cat > /mnt/etc/locale.gen << 'LOCALE'
ru_RU.UTF-8 UTF-8
en_US.UTF-8 UTF-8
LOCALE

  if [[ "$REGION" == "ru" ]]; then
    echo "LANG=ru_RU.UTF-8" > /mnt/etc/locale.conf
    echo "KEYMAP=ru" > /mnt/etc/vconsole.conf
    echo "FONT=cyr-sun16" >> /mnt/etc/vconsole.conf
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime 2>/dev/null || true
  else
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
    echo "KEYMAP=us" > /mnt/etc/vconsole.conf
    echo "" >> /mnt/etc/vconsole.conf
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/UTC /etc/localtime 2>/dev/null || true
  fi

  arch-chroot /mnt locale-gen 2>/dev/null || true
  echo "$HOSTNAME" > /mnt/etc/hostname

  cat > /mnt/etc/hosts << 'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   HOSTNAME_PLACEHOLDER
HOSTS
  sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/" /mnt/etc/hosts

  arch-chroot /mnt useradd -m -G wheel,audio,video,storage -s /bin/bash "$USERNAME" 2>/dev/null || true
  echo "$USERNAME:$PASSWORD" | arch-chroot /mnt chpasswd
  echo "root:root" | arch-chroot /mnt chpasswd

  echo "%wheel ALL=(ALL:ALL) ALL" >> /mnt/etc/sudoers.d/wheel
  chmod 440 /mnt/etc/sudoers.d/wheel

  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=HackerRUB --recheck 2>/dev/null || true

  cat > /mnt/etc/default/grub << 'GRUB'
# HWOS — GRUB configuration
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="HWOS"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nowatchdog"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TERMINAL_OUTPUT="gfxterm"
GRUB_GFXMODE="1920x1080,1280x720,auto"
GRUB_GFXPAYLOAD_LINUX="keep"
GRUB_THEME="/boot/grub/themes/hackerrub/theme.txt"
GRUB_DISABLE_OS_PROBER=false
GRUB_ENABLE_CRYPTODISK=n
GRUB_DISABLE_RECOVERY=true
GRUB_SAVEDEFAULT=true
GRUB_FONT="/boot/grub/fonts/hack.pf2"
GRUB_COLOR_NORMAL="white/black"
GRUB_COLOR_HIGHLIGHT="blue/black"
GRUB_BADRAM="0x0,0x0"
GRUB_TIMEOUT_STYLE=menu
GRUB_INIT_TUNE="480 440 1"
GRUB_DISTRIBUTOR_ICON="hwos"
GRUB_BOOT_MENU_ENTRIES="auto"
GRUB_DISABLE_SUBMENU=y
GRUB_DISABLE_LINUX_UUID=false
GRUB_DISABLE_LINUX_PARTUUID=false
GRUB_VIDEO_BACKEND="efi_uga,efi_gop"
GRUB_GFXPAYLOAD="keep"
GRUB_SERIAL_COMMAND="serial"
GRUB_TERMINAL_INPUT="console,serial"
GRUB_CMDLINE_NET=""
GRUB_HIDDEN_TIMEOUT=""
GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_RECORDFAIL_TIMEOUT=-1
GRUB_DISABLE_OS_PROBER_DEFAULT=false
GRUB_SAVEDEFAULT=true
GRUB_THEME="/boot/grub/themes/hackerrub/theme.txt"
GRUB_DISTRIBUTOR="HWOS — Сделано в Санкт-Петербурге"
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nowatchdog mitigations=auto spectre_v2=on spec_store_bypass_disable=on"

if [ -f ${config_directory}/custom.cfg ]; then
  . ${config_directory}/custom.cfg
fi
GRUB

  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true

  arch-chroot /mnt systemctl enable NetworkManager 2>/dev/null || true
  arch-chroot /mnt systemctl enable systemd-timesyncd 2>/dev/null || true
}

final_message() {
  dialog --title "$($(L_ "Установка завершена" "Installation Complete"))" \
    --msgbox "$($(L_ "HWOS установлена!
Регион: $REGION
Пользователь: $USERNAME

После перезагрузки вы попадёте в HWOS.

Сделано в Санкт-Петербурге ❤️" "HWOS is installed!
Region: $REGION
User: $USERNAME

After reboot you'll be in HWOS.

Made in Saint Petersburg ❤️"))" 12 50
}

# ============================================================
# MAIN
# ============================================================
main() {
  check_root
  cleanup
  trap cleanup EXIT

  select_region
  select_language
  select_mode
  select_disk
  select_partitions
  detect_partitions
  format_partitions
  mount_partitions
  get_user_info

  run_pacstrap || {
    dialog --title "$($(L_ "Ошибка" "Error"))" \
      --msgbox "$($(L_ "Установка не удалась. Проверьте подключение к интернету." "Installation failed. Check your internet connection."))" 6 50
    exit 1
  }

  configure_system
  final_message

  dialog --title "$($(L_ "Готово" "Done"))" \
    --yesno "$($(L_ "Перезагрузить сейчас?" "Reboot now?"))" 6 40
  [[ $? -eq 0 ]] && reboot
}

main "$@"
