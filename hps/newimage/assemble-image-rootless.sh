#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
#
# Loopless alternative to assemble-image.sh: builds the identical DE1-SoC SD
# image WITHOUT loop devices or mounts. It makes each partition as a plain
# file (mkfs.ext4 -d for the rootfs, mtools for the FAT boot partition) and
# splices them into the image with dd, so it runs where losetup/mount are
# unavailable — inside an unprivileged container, or on a host without root
# for loop setup (e.g. CI). Partition layout and contents are identical to
# assemble-image.sh:
#   p1 FAT (boot) @2048 | p2 type-A2 (vendor preloader+U-Boot) | p3 ext4 (rootfs)
#
# Needs: mkfs.ext4 (e2fsprogs), mkfs.vfat + mcopy (dosfstools, mtools), sfdisk
# (util-linux/fdisk), dd. Run after `make kernel dtbocfg rootfs` has populated
# kernel/, rootfs/, and modules. Compare with assemble-image.sh, which uses the
# loop-device path when root + /dev are available.
set -e
BASE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"   # = newimage/
KERN=$BASE/kernel/linux-6.12
R=$BASE/rootfs
VA2=$BASE/fpga/vendor-a2-preloader-uboot.bin
IMG=$BASE/image/de1soc-debian12-6.12.img

FAT_MB=256; A2_MB=2; EXT_MB=1536
FAT_START=2048;                   FAT_SIZE=$((FAT_MB*2048))   # p1
A2_START=$((FAT_START+FAT_SIZE)); A2_SIZE=$((A2_MB*2048))     # p2
ROOT_START=$((A2_START+A2_SIZE)); ROOT_SIZE=$((EXT_MB*2048))  # p3 (last)
END=$((ROOT_START+ROOT_SIZE))
TOTAL_MB=$(( END/2048 + 8 ))
TMP=$(mktemp -d)

echo "[*] finalize rootfs tree (same edits the original makes on the mounted fs)"
rm -f "$R/usr/bin/qemu-arm-static"
install -m 0755 "$BASE/expand-rootfs.sh" "$R/usr/local/sbin/expand-rootfs.sh"
install -m 0755 "$BASE/../../fpga/fpga-load/fpga-load.sh" "$R/usr/local/sbin/fpga-load.sh"
mkdir -p "$R/usr/share/doc/de1soc-open-source-licenses"
cp -a "$BASE/legal/." "$R/usr/share/doc/de1soc-open-source-licenses/"
rm -rf "$R/var/log/journal"
install -d -m 2755 "$R/var/log/journal"
chown 0:999 "$R/var/log/journal"

echo "[*] p3: ext4 from rootfs tree (mkfs.ext4 -d, no mount)"
rm -f "$TMP/root.img"; truncate -s ${EXT_MB}M "$TMP/root.img"
mkfs.ext4 -q -L rootfs -d "$R" "$TMP/root.img"

echo "[*] p1: FAT boot files via mtools (no mount)"
rm -f "$TMP/fat.img"; truncate -s ${FAT_MB}M "$TMP/fat.img"
mkfs.vfat -F32 -n BOOT "$TMP/fat.img" >/dev/null
mcopy -i "$TMP/fat.img" "$KERN/arch/arm/boot/zImage" ::zImage
mcopy -i "$TMP/fat.img" "$KERN/arch/arm/boot/dts/intel/socfpga/socfpga_cyclone5_de1_soc.dtb" ::socfpga.dtb
mcopy -i "$TMP/fat.img" "$BASE/fpga/soc_system.rbf" ::soc_system.rbf
mcopy -i "$TMP/fat.img" "$BASE/image/u-boot.scr" ::u-boot.scr

echo "[*] create $IMG (${TOTAL_MB} MiB) + partition table"
rm -f "$IMG"; truncate -s ${TOTAL_MB}M "$IMG"
sfdisk "$IMG" >/dev/null <<EOF
label: dos
${FAT_START},${FAT_SIZE},0c
${A2_START},${A2_SIZE},a2
${ROOT_START},${ROOT_SIZE},83
EOF

echo "[*] splice partitions into the image"
dd if="$TMP/fat.img" of="$IMG" bs=512 seek=$FAT_START conv=notrunc,sparse status=none
dd if="$VA2"         of="$IMG" bs=512 seek=$A2_START  conv=notrunc status=none
dd if="$TMP/root.img" of="$IMG" bs=512 seek=$ROOT_START conv=notrunc,sparse status=none

rm -rf "$TMP"
echo "[*] DONE: $IMG  ($(du -h "$IMG" | cut -f1) on disk)"
