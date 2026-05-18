#!/usr/bin/env bash
# hwos-chroot-setup - Apply HWOS configuration in chroot
set -euo pipefail

echo "[*] HWOS Chroot Setup"

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "hwos" > /etc/hostname

cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   hwos.localdomain hwos
HOSTS

echo "root:hwos" | chpasswd

useradd -m -G wheel,audio,video,network,storage,docker -s /usr/bin/hacker hacker
echo "hacker:hwos" | chpasswd

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "Defaults timestamp_timeout=15" >> /etc/sudoers.d/hwos

systemctl enable NetworkManager
systemctl enable iwd
systemctl enable sddm
systemctl enable bluetooth
systemctl enable fstrim.timer

hackerrub-config 2>/dev/null || true
hwos-setup-fastfetch 2>/dev/null || true

mkinitcpio -P

echo "[+] HWOS chroot setup complete!"
