#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
# Build the Debian 12 (bookworm) armhf rootfs via debootstrap (two-stage +
# qemu-arm-static), then configure it for the DE1-SoC. Run as root:
#   pkexec bash make-rootfs.sh     (or: sudo bash make-rootfs.sh)
#
# Requires on the host: debootstrap, qemu-user-static, binfmt-support.
# The kernel modules must already be staged (run `make kernel` first) — see
# configure-rootfs.sh, which copies them in.
set -e
# Resolve this script's own directory so the tree works from any clone location.
BASE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
R="$BASE/rootfs"
SUITE=bookworm
MIRROR=http://deb.debian.org/debian

# Packages beyond the minimal base set:
#  - dbus/dbus-user-session: the system message bus — WITHOUT these, hostnamectl
#    / timedatectl / localectl fail with "Failed to connect to bus".
#  - the rest give a usable headless system (ssh, sudo, DHCP, NTP, locales).
INCLUDE=dbus,dbus-user-session,sudo,openssh-server,ca-certificates,locales,kmod,systemd-sysv,systemd-timesyncd,iproute2

[ "$(id -u)" = 0 ] || { echo "run as root:  pkexec bash $0"; exit 1; }
command -v debootstrap >/dev/null || { echo "missing: debootstrap (run 'make deps')"; exit 1; }
[ -e /usr/bin/qemu-arm-static ] || { echo "missing: qemu-arm-static (run 'make deps')"; exit 1; }

echo "[*] debootstrap stage 1 (foreign, armhf $SUITE) -> $R"
rm -rf "$R"; mkdir -p "$R"
debootstrap --arch=armhf --foreign --include="$INCLUDE" "$SUITE" "$R" "$MIRROR"

echo "[*] qemu-arm-static + debootstrap stage 2"
cp -f /usr/bin/qemu-arm-static "$R/usr/bin/"
chroot "$R" /debootstrap/debootstrap --second-stage

echo "[*] configure rootfs (users, network, journal, modules, ...)"
bash "$BASE/configure-rootfs.sh"

echo "[*] DONE: rootfs at $R"
