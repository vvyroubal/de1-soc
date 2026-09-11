#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
# Configure the debootstrapped Debian 12 armhf rootfs for the DE1-SoC.
# Run as root (pkexec) AFTER debootstrap --second-stage completes.
set -e
# Resolve this script's own directory so the tree works from any clone location.
BASE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
R=$BASE/rootfs
MODSRC=$BASE/modules-staging/lib/modules

echo "[*] hostname + hosts"
echo de1-soc-debian > "$R/etc/hostname"
cat > "$R/etc/hosts" <<EOF
127.0.0.1   localhost
127.0.1.1   de1-soc-debian
::1         localhost ip6-localhost ip6-loopback
EOF

echo "[*] apt sources (bookworm)"
cat > "$R/etc/apt/sources.list" <<EOF
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

echo "[*] fstab"
cat > "$R/etc/fstab" <<EOF
/dev/mmcblk0p3  /      ext4  defaults,noatime  0 1
/dev/mmcblk0p1  /boot  vfat  defaults          0 2
proc            /proc  proc  defaults          0 0
EOF

echo "[*] journald: persistent storage, capped at 512M"
# journald runs as root and creates /var/log/journal/<machine-id> with group
# ROOT; it does NOT set the systemd-journal group itself (on a full system that's
# systemd-tmpfiles' job, which doesn't run on this minimal image). So a non-root
# journalctl fails ("insufficient permissions"). Fix: pre-create /var/log/journal
# with the SETGID bit + group systemd-journal (done in the chroot block below),
# so every subdir/file journald creates INHERITS the systemd-journal group and
# the debian user (a member) can read it. Drop-in = persistent storage + 512M cap.
mkdir -p "$R/etc/systemd/journald.conf.d"
cat > "$R/etc/systemd/journald.conf.d/00-de1soc.conf" <<EOF
[Journal]
Storage=persistent
SystemMaxUse=512M
EOF

echo "[*] systemd-networkd DHCP on eth0"
mkdir -p "$R/etc/systemd/network"
cat > "$R/etc/systemd/network/10-eth.network" <<EOF
[Match]
Name=eth0 en*
[Network]
DHCP=yes
EOF

echo "[*] install kernel modules (6.12.0)"
mkdir -p "$R/lib/modules"
cp -a "$MODSRC/6.12.0" "$R/lib/modules/"

echo "[*] chroot config (users, services) via qemu"
cp -f /usr/bin/qemu-arm-static "$R/usr/bin/" 2>/dev/null || true
chroot "$R" /bin/bash -e <<'CHROOT'
export DEBIAN_FRONTEND=noninteractive
echo 'root:temppwd' | chpasswd
id debian >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo,adm,systemd-journal debian
echo 'debian:temppwd' | chpasswd
systemctl enable serial-getty@ttyS0.service
systemctl enable ssh
systemctl enable systemd-networkd
systemctl enable systemd-resolved || true
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf || true
# Persistent-journal dir: setgid + group systemd-journal so journald's files
# inherit the group and non-root (debian, a member) can read them.
install -d -o root -g systemd-journal -m 2755 /var/log/journal
depmod 6.12.0 || true
CHROOT

echo "[*] done. rootfs size: $(du -sh "$R" | cut -f1)"
