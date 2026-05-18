#!/usr/bin/env bash
# hwos-installer - Hacker Web OS Dialog-based Installer
# Version: 1.0.0

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
VERSION="1.0.0"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        exec sudo "$0" "$@"
    fi
}

check_deps() {
    local deps=("dialog" "parted" "mkfs.ext4" "mkfs.btrfs" "cryptsetup" "arch-chroot")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo -e "${RED}[!] Missing dependency: $dep${NC}"
            exit 1
        fi
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
    Hacker Web OS\n\
    https://hwos.dev\n\n\
    Press OK to begin installation..." 15 50
}

select_language() {
    LANG=$(dialog --clear --stdout \
        --title "Language" \
        --menu "Select installation language:" \
        12 40 4 \
        "en" "English" \
        "ru" "Русский" \
        "de" "Deutsch" \
        "fr" "Français")
    export LANG
}

select_disk() {
    local disks=()
    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $4}')
        size=$(echo "$line" | awk '{print $3}')
        model=$(echo "$line" | cut -d' ' -f5-)
        disks+=("$name" "$model ($size)")
    done < <(lsblk -d -o NAME,SIZE,TYPE,MODEL -n -p 2>/dev/null | grep -E 'sd|nvme|vd')

    if [[ ${#disks[@]} -eq 0 ]]; then
        dialog --title "Error" --msgbox "No disks found!" 5 40
        exit 1
    fi

    DISK=$(dialog --clear --stdout \
        --title "Disk Selection" \
        --menu "Select target disk (ALL DATA WILL BE WIPED):" \
        15 60 5 "${disks[@]}")
    export DISK
}

select_filesystem() {
    FSTYPE=$(dialog --clear --stdout \
        --title "Filesystem" \
        --menu "Select filesystem type:" \
        12 45 4 \
        "btrfs" "BTRFS (recommended, snapshots)" \
        "ext4" "Ext4 (classic)" \
        "xfs" "XFS (high performance)")
    export FSTYPE
}

select_encryption() {
    dialog --title "Encryption" --yesno "Enable LUKS full disk encryption?" 7 45
    ENCRYPT=$([ $? -eq 0 ] && echo "yes" || echo "no")
    export ENCRYPT
    if [[ "$ENCRYPT" == "yes" ]]; then
        PASS1=$(dialog --clear --stdout --title "Encryption Password" --passwordbox "Enter LUKS password:" 8 50)
        PASS2=$(dialog --clear --stdout --title "Confirm Password" --passwordbox "Confirm password:" 8 50)
        if [[ "$PASS1" != "$PASS2" ]]; then
            dialog --title "Error" --msgbox "Passwords do not match!" 5 40
            select_encryption
        fi
        LUKS_PASS="$PASS1"
        export LUKS_PASS
    fi
}

select_hostname() {
    HOSTNAME=$(dialog --clear --stdout \
        --title "Hostname" \
        --inputbox "Enter hostname for this machine:" \
        8 50 "hwos")
    export HOSTNAME
}

create_user() {
    USERNAME=$(dialog --clear --stdout \
        --title "User Account" \
        --inputbox "Enter username for primary user:" \
        8 50 "hacker")
    PASS1=$(dialog --clear --stdout --title "User Password" --passwordbox "Enter password for $USERNAME:" 8 50)
    PASS2=$(dialog --clear --stdout --title "Confirm Password" --passwordbox "Confirm password:" 8 50)
    if [[ "$PASS1" != "$PASS2" ]]; then
        dialog --title "Error" --msgbox "Passwords do not match!" 5 40
        create_user
    fi
    USER_PASS="$PASS1"
    export USERNAME USER_PASS
}

select_wm() {
    WM=$(dialog --clear --stdout \
        --title "Window Manager" \
        --menu "Select default window manager:" \
        15 50 5 \
        "hyprland" "Hyprland (Wayland, modern, default)" \
        "i3" "i3 WM (Tiling)" \
        "sway" "Sway (i3-compatible Wayland)" \
        "none" "No WM (CLI only)")
    export WM
}

select_kernel() {
    KERNEL=$(dialog --clear --stdout \
        --title "Kernel" \
        --menu "Select kernel:" \
        10 45 2 \
        "linux-6.1" "Linux 6.1 LTS (default)" \
        "linux" "Linux latest stable")
    export KERNEL
}

install_system() {
    (
    echo "10" ; sleep 1
    echo "XXX"; echo "Partitioning disk..."; echo "XXX"

    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart primary linux-swap 512MiB 4GiB
    parted -s "$DISK" mkpart primary 4GiB 100%

    mkfs.fat -F32 "${DISK}1"
    mkswap "${DISK}2"
    swapon "${DISK}2"

    if [[ "$ENCRYPT" == "yes" ]]; then
        echo -n "$LUKS_PASS" | cryptsetup luksFormat "${DISK}3"
        echo -n "$LUKS_PASS" | cryptsetup open "${DISK}3" hwos_root
        ROOT_DEV="/dev/mapper/hwos_root"
    else
        ROOT_DEV="${DISK}3"
    fi

    echo "30"
    echo "XXX"; echo "Formatting $FSTYPE..."; echo "XXX"

    case "$FSTYPE" in
        btrfs)
            mkfs.btrfs -f "$ROOT_DEV"
            mount "$ROOT_DEV" /mnt
            btrfs subvolume create /mnt/@
            btrfs subvolume create /mnt/@home
            btrfs subvolume create /mnt/@snapshots
            btrfs subvolume create /mnt/@cache
            btrfs subvolume create /mnt/@log
            umount /mnt
            mount -o compress=zstd,subvol=@ "$ROOT_DEV" /mnt
            mkdir -p /mnt/{home,.snapshots,var/cache,var/log,boot}
            mount -o compress=zstd,subvol=@home "$ROOT_DEV" /mnt/home
            mount -o compress=zstd,subvol=@snapshots "$ROOT_DEV" /mnt/.snapshots
            mount -o compress=zstd,subvol=@cache "$ROOT_DEV" /mnt/var/cache
            mount -o compress=zstd,subvol=@log "$ROOT_DEV" /mnt/var/log
            ;;
        ext4)
            mkfs.ext4 -F "$ROOT_DEV"
            mount "$ROOT_DEV" /mnt
            mkdir -p /mnt/boot
            ;;
        xfs)
            mkfs.xfs -f "$ROOT_DEV"
            mount "$ROOT_DEV" /mnt
            mkdir -p /mnt/boot
            ;;
    esac

    mount "${DISK}1" /mnt/boot

    echo "50"
    echo "XXX"; echo "Installing base system..."; echo "XXX"

    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

    cat >> /etc/pacman.conf <<EOF

[hwos]
SigLevel = Optional TrustAll
Server = https://repo.hwos.dev/\$arch
EOF

    pacstrap -K /mnt base base-devel hwos-scripts hwos-configs hwos-theme hwins \
        "$KERNEL" "$KERNEL-headers" linux-firmware \
        grub hackerrub efibootmgr networkmanager iwd \
        "$WM" sddm pipewire pipewire-pulse wireplumber \
        nftables fastfetch zsh git hacker-shell

    echo "70"
    echo "XXX"; echo "Configuring system..."; echo "XXX"

    genfstab -U /mnt >> /mnt/etc/fstab

    arch-chroot /mnt /bin/bash <<CHROOT
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

systemctl enable NetworkManager
systemctl enable iwd
systemctl enable sddm
systemctl enable bluetooth
systemctl enable fstrim.timer

usermod --shell /usr/bin/hacker root

useradd -m -G wheel,audio,video,network,storage,docker -s /usr/bin/hacker "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd
echo "root:$USER_PASS" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=HackerRUB
grub-mkconfig -o /boot/grub/grub.cfg

hwos-setup-fastfetch
CHROOT

    echo "90"
    echo "XXX"; echo "Finalizing..."; echo "XXX"

    umount -R /mnt

    echo "100"
    echo "XXX"; echo "Installation complete!"; echo "XXX"
    ) | dialog --title "Installing HWOS" --gauge "Preparing..." 8 50 0
}

summary() {
    dialog --title "Installation Summary" --msgbox "\n\
    HWOS Installation Complete!\n\n\
    Disk: $DISK\n\
    Filesystem: $FSTYPE\n\
    Encryption: $ENCRYPT\n\
    WM: $WM\n\
    Kernel: $KERNEL\n\
    User: $USERNAME\n\n\
    Reboot to start your Hacker Web OS!" 15 55
}

main() {
    check_root
    check_deps

    show_logo
    select_language
    select_disk
    select_filesystem
    select_encryption
    select_hostname
    create_user
    select_wm
    select_kernel

    dialog --title "Confirm" --yesno "Ready to install HWOS to $DISK?\n\nAll data on $DISK will be wiped!" 8 50
    case $? in
        0) install_system ;;
        1) dialog --title "Cancelled" --msgbox "Installation cancelled." 5 40; exit 1 ;;
    esac

    summary
    dialog --title "Reboot" --yesno "Reboot now?" 5 30
    [[ $? -eq 0 ]] && reboot
}

main "$@"
