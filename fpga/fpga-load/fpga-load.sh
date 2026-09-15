#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
#
# fpga-load.sh -- reconfigure the DE1-SoC FPGA fabric at runtime from HPS Linux.
#
# Works for any self-contained fabric design on the mainline (6.12) image. It
# stages your bitstream at /lib/firmware/fpga.rbf and applies a device-tree
# overlay (naming that firmware) to the base FPGA region, so the FPGA Manager
# programs the fabric. Overlays are applied from userspace via the `dtbocfg`
# configfs module (mainline has no built-in userspace overlay interface).
#
# Usage (auto-elevates with sudo):
#   ./fpga-load.sh <design.rbf>     stage a bitstream in /lib/firmware and load it
#   ./fpga-load.sh -a | --apply     load the already-staged /lib/firmware/fpga.rbf
#   ./fpga-load.sh -u | --unload    remove the overlay (release the region)
#   ./fpga-load.sh -s | --status    show overlay + FPGA-manager state
#
# The .rbf MUST be uncompressed (MSEL=00000 / FPP). Generate with:
#   quartus_cpf -c -o bitstream_compression=off design.sof design.rbf
set -euo pipefail

OVERLAY_NAME="fpga"
FW_DIR="/lib/firmware"
RBF_DEST="$FW_DIR/fpga.rbf"
CONFIGFS="/sys/kernel/config"
OVL_DIR="$CONFIGFS/device-tree/overlays/$OVERLAY_NAME"
FPGA_STATE="/sys/class/fpga_manager/fpga0/state"

# Generic overlay, compiled: target-path=/soc/base_fpga_region, firmware-name="fpga.rbf".
DTBO_B64="0A3+7QAAAMYAAAA4AAAArAAAACgAAAARAAAAEAAAAAAAAAAaAAAAdAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAFmcmFnbWVudEAwAAAAAAADAAAAFgAAAAAvc29jL2Jhc2VfZnBnYV9yZWdpb24AAAAAAAABX19vdmVybGF5X18AAAAAAwAAAAkAAAAMZnBnYS5yYmYAAAAAAAAAAgAAAAIAAAACAAAACXRhcmdldC1wYXRoAGZpcm13YXJlLW5hbWUA"

die() { echo "fpga-load: error: $*" >&2; exit 1; }
usage() { echo "Usage: $0 <design.rbf> | -a|--apply | -u|--unload | -s|--status"; }

[ "$(id -u)" -eq 0 ] || exec sudo -- "$0" "$@"

ensure_overlays() {
    modprobe dtbocfg 2>/dev/null || true          # provides configfs overlays iface
    [ -d "$CONFIGFS/device-tree" ] || mount -t configfs none "$CONFIGFS" 2>/dev/null || true
    [ -d "$CONFIGFS/device-tree/overlays" ] \
        || die "no configfs overlays dir — is the dtbocfg module present? (modprobe dtbocfg)"
}

remove_overlay() { [ -d "$OVL_DIR" ] && rmdir "$OVL_DIR" || true; }

apply_staged() {
    ensure_overlays
    [ -f "$RBF_DEST" ] || die "no staged bitstream at $RBF_DEST — run '$0 <design.rbf>' first"
    remove_overlay
    mkdir "$OVL_DIR"
    # Applying = writing the compiled overlay blob to the dtbocfg 'dtbo' attribute.
    if ! base64 -d <<<"$DTBO_B64" > "$OVL_DIR/dtbo" 2>/dev/null; then
        remove_overlay; die "overlay apply failed — check: dmesg | tail"
    fi
    sleep 1
    local st; st=$(cat "$FPGA_STATE" 2>/dev/null || echo unknown)
    echo "FPGA manager state : $st"
    [ "$st" = "operating" ] || { remove_overlay; die "reconfig did not complete (state=$st). Check: dmesg | tail"; }
    echo "OK: fabric configured from $RBF_DEST"
}

do_load() {
    local rbf="$1"; [ -f "$rbf" ] || die "bitstream not found: $rbf"
    local sz; sz=$(stat -c %s "$rbf")
    [ "$sz" -ge 3000000 ] || echo "fpga-load: warning: '$rbf' is $sz bytes — looks COMPRESSED;" \
        "MSEL=00000 needs an uncompressed .rbf (quartus_cpf -o bitstream_compression=off)." >&2
    ensure_overlays
    mkdir -p "$FW_DIR"                     # minimal rootfs may lack /lib/firmware
    install -m 0644 "$rbf" "$RBF_DEST"
    apply_staged
}

case "${1:-}" in
    -a|--apply)  apply_staged ;;
    -u|--unload) ensure_overlays; remove_overlay && echo "Overlay removed (region released)." ;;
    -s|--status) ensure_overlays
                 [ -r "$FPGA_STATE" ] && echo "FPGA manager state : $(cat "$FPGA_STATE")"
                 [ -d "$OVL_DIR" ] && echo "Overlay '$OVERLAY_NAME' : applied" || echo "Overlay '$OVERLAY_NAME' : not applied"
                 [ -f "$RBF_DEST" ] && echo "Staged bitstream   : $RBF_DEST ($(stat -c %s "$RBF_DEST") bytes)" ;;
    -h|--help|"") usage ;;
    -*)          die "unknown option: $1" ;;
    *)           do_load "$1" ;;
esac
