#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
# expand-rootfs.sh -- grow the Debian rootfs (/dev/mmcblk0p3) to fill the SD card.
#
# The image ships small (~1.8 GB) so it flashes onto any card; run this once from
# Debian to use the card's full size. The rootfs is the LAST partition on disk,
# so this simply extends p3 to the end and schedules an on-boot resize2fs.
set -euo pipefail

DISK=/dev/mmcblk0
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
command -v sfdisk >/dev/null || { echo "missing tool: sfdisk"; exit 1; }

echo "Extending ${DISK}p3 to fill the card..."
# p2 is the last partition: keep its start, grow size to all free space.
echo ", +" | sfdisk -N 3 --no-reread --no-tell-kernel "$DISK"

# resize2fs runs once on next boot (kernel re-reads the enlarged table then).
cat > /etc/systemd/system/resize-rootfs-once.service <<'UNIT'
[Unit]
Description=Grow rootfs to fill its partition (one-shot)
After=local-fs.target
ConditionPathExists=/usr/sbin/resize2fs
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/resize2fs /dev/mmcblk0p3
ExecStartPost=/usr/bin/systemctl disable resize-rootfs-once.service
[Install]
WantedBy=multi-user.target
UNIT
systemctl enable resize-rootfs-once.service
sync

echo
echo "Done. Reboot to apply:  sudo reboot"
echo "After reboot, check:    df -h /"
