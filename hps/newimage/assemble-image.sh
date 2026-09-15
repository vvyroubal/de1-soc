#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
# Assemble the DE1-SoC Debian 12 / Linux 6.12 SD image.
# Layout (partition numbers == disk order; rootfs LAST so it grows trivially):
#   p1 FAT (boot) @2048 | p2 type-A2 (vendor preloader+U-Boot) | p3 ext4 (rootfs, last)
# U-Boot: FAT is still `mmc 0:1`; A2 is found by partition TYPE (0xa2), not number;
# rootfs is p3 and u-boot.scr overrides the vendor env's mmcroot to /dev/mmcblk0p3.
set -e
# Resolve this script's own directory so the tree works from any clone location.
BASE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
KERN=$BASE/kernel/linux-6.12
R=$BASE/rootfs
VA2=$BASE/fpga/vendor-a2-preloader-uboot.bin      # proven vendor preloader+U-Boot
IMG=$BASE/image/de1soc-debian12-6.12.img

FAT_MB=256; A2_MB=2; EXT_MB=1536

# sectors (contiguous; starts strictly increasing so part numbers == disk order)
FAT_START=2048;                   FAT_SIZE=$((FAT_MB*2048))   # p1
A2_START=$((FAT_START+FAT_SIZE)); A2_SIZE=$((A2_MB*2048))     # p2
ROOT_START=$((A2_START+A2_SIZE)); ROOT_SIZE=$((EXT_MB*2048))  # p3 (last)
END=$((ROOT_START+ROOT_SIZE))
TOTAL_MB=$(( END/2048 + 8 ))

echo "[*] create $IMG (${TOTAL_MB} MiB)"
rm -f "$IMG"; truncate -s ${TOTAL_MB}M "$IMG"

echo "[*] partition (MBR, in disk order): p1 FAT, p2 A2, p3 ext4 (rootfs, last)"
sfdisk "$IMG" >/dev/null <<EOF
label: dos
${FAT_START},${FAT_SIZE},0c
${A2_START},${A2_SIZE},a2
${ROOT_START},${ROOT_SIZE},83
EOF

echo "[*] loop attach"; LOOP=$(losetup --show -f -P "$IMG"); echo "    $LOOP"; sync; sleep 1

echo "[*] mkfs"
mkfs.vfat -F32 -n BOOT ${LOOP}p1 >/dev/null
mkfs.ext4 -q -L rootfs ${LOOP}p3

echo "[*] vendor preloader+U-Boot -> A2 (p2)"
dd if="$VA2" of=${LOOP}p2 bs=1M conv=fsync status=none

echo "[*] FAT boot files (p1)"
m=$(mktemp -d); mount ${LOOP}p1 "$m"
cp "$KERN/arch/arm/boot/zImage" "$m/zImage"
cp "$KERN/arch/arm/boot/dts/intel/socfpga/socfpga_cyclone5_de1_soc.dtb" "$m/socfpga.dtb"
cp "$BASE/fpga/soc_system.rbf" "$m/soc_system.rbf"
cp "$BASE/image/u-boot.scr" "$m/u-boot.scr"
sync; umount "$m"

echo "[*] rootfs -> ext4 (p3, last partition)"
mount ${LOOP}p3 "$m"
cp -a "$R/." "$m/"
rm -f "$m/usr/bin/qemu-arm-static"
install -m 0755 "$BASE/expand-rootfs.sh" "$m/usr/local/sbin/expand-rootfs.sh"
install -m 0755 "$BASE/../../fpga/fpga-load/fpga-load.sh" "$m/usr/local/sbin/fpga-load.sh"
# Open-source license notices + corresponding-source bundle (GPL compliance)
mkdir -p "$m/usr/share/doc/de1soc-open-source-licenses"
cp -a "$BASE/legal/." "$m/usr/share/doc/de1soc-open-source-licenses/"
# Persistent journal dir, SETGID + group systemd-journal (GID 999 in the target).
# journald creates /var/log/journal/<machine-id> as group ROOT (it doesn't set
# the systemd-journal group itself, and systemd-tmpfiles doesn't run on this
# minimal image), so without setgid the debian user can't read the journal. The
# setgid bit makes journald's new subdir/files inherit systemd-journal. Combined
# with the journald.conf.d drop-in (Storage=persistent, SystemMaxUse=512M).
rm -rf "$m/var/log/journal"
install -d -m 2755 "$m/var/log/journal"
chown 0:999 "$m/var/log/journal"
sync; umount "$m"; rmdir "$m"

echo "[*] detach"; losetup -d "$LOOP"
echo "[*] DONE: $IMG  ($(du -h "$IMG" | cut -f1) on disk)"
