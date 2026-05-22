#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="caulklinux"
iso_label="CAULK_$(date +%Y%m)"
iso_publisher="CaulkLinux <https://github.com/legendarymsr/caulklinux>"
iso_application="CaulkLinux"
iso_version="$(date +%Y.%m)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/usr/bin/caulk-install"]="0:0:755"
)
