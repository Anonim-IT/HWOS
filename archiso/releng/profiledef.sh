#!/usr/bin/env bash
# vim: set sw=4 et sts=4 tw=72 :

set -e -u

iso_name=hwos
iso_label="HWOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Hacker Web OS <https://hwos.dev>"
iso_application="Hacker Web OS Live/Rescue DVD"
iso_version=$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)
install_dir=hwos
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.grub.esp' 'uefi-x64.grub.esp'
           'uefi-ia32.grub.eltorito' 'uefi-x64.grub.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="erofs+luks"
airootfs_image_tool_options=('-zlzo' '-E' 'ztailpacking')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:700"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/hwos-installer"]="0:0:755"
  ["/usr/local/bin/hwins"]="0:0:755"
  ["/usr/bin/hacker"]="0:0:755"
  ["/etc/skel/.hackerrc"]="0:0:644"
)
