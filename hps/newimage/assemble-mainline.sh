#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
# Assemble a 100%-MAINLINE DE1-SoC image (mainline U-Boot 2026.07 SPL+proper).
#
# EXPERIMENTAL / NOT THE SHIPPING PATH: the mainline socfpga gen5 SPL cannot read
# the SD card on this board (data-phase failure), so this image does not boot.
# It is kept only for future SPL debugging. The supported image is built with
# the Makefile / assemble-image.sh (vendor-preloader hybrid).
#
# Key difference vs the vendor-preloader image: the type-A2 partition starts at
# SECTOR 512, because the mainline socfpga SPL reads U-Boot proper from the
# hard-coded absolute sector (SPL_PAD_TO*4)/512 + 0x200 = 1024, which only works
# if u-boot-with-spl.sfp begins at sector 512.
#   Layout: A2 @512 (sfp) | FAT @2048 | ext4 (last, rootfs)
set -e
# Resolve this script's own directory so the tree works from any clone location.
BASE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Path to a built mainline u-boot tree (contains u-boot-with-spl.sfp). Not part
# of this repo — build it yourself and point U at it, or override: U=/path make ...
U="${U:-$BASE/../sdcard/build/u-boot}"
[ -f "$U/u-boot-with-spl.sfp" ] || { echo "experimental: build mainline U-Boot and set U= (no u-boot-with-spl.sfp at $U)"; exit 1; }
KERN=$BASE/kernel/linux-6.12
R=$BASE/rootfs
IMG=$BASE/image/de1soc-debian12-6.12-mainline.img

FAT_MB=256; EXT_MB=1536
A2_START=512; A2_SIZE=1536                      # 512..2047 (768 KiB; sfp is 672 KiB)
P1_START=2048;                  P1_SIZE=$((FAT_MB*2048))
P2_START=$((P1_START+P1_SIZE)); P2_SIZE=$((EXT_MB*2048))
END=$((P2_START+P2_SIZE)); TOTAL_MB=$(( END/2048 + 8 ))

echo "[*] create $IMG (${TOTAL_MB} MiB)"
rm -f "$IMG"; truncate -s ${TOTAL_MB}M "$IMG"

echo "[*] partition: p1 FAT @2048, p2 ext4 (last), p3 A2 @512"
sfdisk "$IMG" >/dev/null <<EOF
label: dos
${P1_START},${P1_SIZE},0c
${P2_START},${P2_SIZE},83
${A2_START},${A2_SIZE},a2
EOF

LOOP=$(losetup --show -f -P "$IMG"); echo "    $LOOP"; sync; sleep 1
mkfs.vfat -F32 -n BOOT ${LOOP}p1 >/dev/null
mkfs.ext4 -q -L rootfs ${LOOP}p2

echo "[*] mainline u-boot-with-spl.sfp -> A2 (p3, sector 512)"
dd if="$U/u-boot-with-spl.sfp" of=${LOOP}p3 bs=512 conv=fsync status=none

echo "[*] FAT boot files (+ mainline boot.scr)"
m=$(mktemp -d); mount ${LOOP}p1 "$m"
cp "$KERN/arch/arm/boot/zImage" "$m/zImage"
cp "$KERN/arch/arm/boot/dts/intel/socfpga/socfpga_cyclone5_de1_soc.dtb" "$m/"
cp "$BASE/fpga/soc_system.rbf" "$m/soc_system.rbf"
cp "$BASE/image/boot.scr.mainline" "$m/boot.scr"
sync; umount "$m"

echo "[*] rootfs -> ext4 (last)"
mount ${LOOP}p2 "$m"
cp -a "$R/." "$m/"
rm -f "$m/usr/bin/qemu-arm-static"
install -m 0755 "$BASE/expand-rootfs.sh" "$m/usr/local/sbin/expand-rootfs.sh"
sync; umount "$m"; rmdir "$m"

losetup -d "$LOOP"
echo "[*] DONE: $IMG  ($(du -h "$IMG" | cut -f1) on disk)"
