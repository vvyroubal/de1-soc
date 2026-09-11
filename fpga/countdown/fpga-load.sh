#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
#
# fpga-load.sh  --  reconfigure the DE1-SoC FPGA fabric at runtime from HPS Linux.
#
# Generic: works for ANY self-contained fabric design. It copies your bitstream
# to /lib/firmware/fpga.rbf, writes an embedded generic overlay (which names
# fpga.rbf), and applies it via configfs so the FPGA Manager programs the fabric.
#
# Usage (auto-elevates with sudo):
#   ./fpga-load.sh <design.rbf>     copy a bitstream into /lib/firmware and load it
#   ./fpga-load.sh -a | --apply     load the already-staged /lib/firmware/fpga.rbf
#                                    (used by the boot-time service)
#   ./fpga-load.sh -u | --unload    remove the overlay (release the region)
#   ./fpga-load.sh -s | --status    show overlay + FPGA-manager state
#
# Notes:
#   * The .rbf MUST be uncompressed (MSEL=00000 / FPP path). Generate with:
#       quartus_cpf -c design.sof design.rbf      (no bitstream_compression)
#   * For HPS-facing designs (peripherals the HPS drives), this generic overlay
#     is not enough — you need a design-specific overlay with child device nodes.
#
set -euo pipefail

OVERLAY_NAME="fpga"
FW_DIR="/lib/firmware"
RBF_DEST="$FW_DIR/fpga.rbf"
DTBO_DEST="$FW_DIR/fpga.dtbo"
CONFIGFS="/sys/kernel/config"
OVL_DIR="$CONFIGFS/device-tree/overlays/$OVERLAY_NAME"
FPGA_STATE="/sys/class/fpga_manager/fpga0/state"

# Embedded generic overlay (firmware-name = "fpga.rbf", target /soc/base-fpga-region)
DTBO_B64="0A3+7QAAASEAAAA4AAAA7AAAACgAAAARAAAAEAAAAAAAAAA1AAAAtAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAFmcmFnbWVudEAwAAAAAAADAAAAFgAAAAAvc29jL2Jhc2UtZnBnYS1yZWdpb24AAAAAAAADAAAABAAAAAwAAAABAAAAAwAAAAQAAAAbAAAAAQAAAAFfX292ZXJsYXlfXwAAAAADAAAABAAAAAwAAAABAAAAAwAAAAQAAAAbAAAAAQAAAAMAAAAJAAAAJ2ZwZ2EucmJmAAAAAAAAAAIAAAACAAAAAgAAAAl0YXJnZXQtcGF0aAAjYWRkcmVzcy1jZWxscwAjc2l6ZS1jZWxscwBmaXJtd2FyZS1uYW1lAA=="

die() { echo "fpga-load: error: $*" >&2; exit 1; }
usage() { echo "Usage: $0 <design.rbf> | -a|--apply | -u|--unload | -s|--status"; }

# Re-run as root if needed
if [ "$(id -u)" -ne 0 ]; then exec sudo -- "$0" "$@"; fi

ensure_configfs() {
    if [ ! -d "$CONFIGFS/device-tree" ]; then
        mount -t configfs none "$CONFIGFS" 2>/dev/null || true
    fi
    [ -d "$CONFIGFS/device-tree/overlays" ] \
        || die "configfs device-tree overlays unavailable (kernel lacks OF_CONFIGFS)"
}

remove_overlay() {
    [ -d "$OVL_DIR" ] && rmdir "$OVL_DIR"
    return 0
}

# Detach anything driving the FPGA framebuffer before we reconfigure the VIP IP
# out of the fabric. Otherwise a later access to the (now absent) VIP registers
# hangs the CPU on a dead bus while holding console_lock -> whole system wedges.
quiesce_fb() {
    command -v plymouth >/dev/null 2>&1 && plymouth quit 2>/dev/null || true
    for vt in /sys/class/vtconsole/*/; do
        if grep -qi 'frame buffer' "$vt/name" 2>/dev/null; then
            echo 0 > "$vt/bind" 2>/dev/null || true   # unbind fbcon from the fb
        fi
    done
}

# Apply the overlay for the bitstream already staged at /lib/firmware/fpga.rbf.
apply_staged() {
    ensure_configfs
    [ -f "$RBF_DEST" ] || die "no staged bitstream at $RBF_DEST — run '$0 <design.rbf>' first"
    quiesce_fb                                          # release the framebuffer first
    printf '%s' "$DTBO_B64" | base64 -d > "$DTBO_DEST"   # (re)stage generic overlay
    remove_overlay                                        # clear any previous apply
    mkdir "$OVL_DIR"
    if ! echo "fpga.dtbo" > "$OVL_DIR/path" 2>/dev/null; then
        echo "fpga-load: apply failed while writing overlay. Check: dmesg | tail" >&2
        exit 1
    fi
    sleep 1
    local st; st=$(cat "$FPGA_STATE" 2>/dev/null || echo unknown)
    echo "FPGA manager state : $st"
    [ "$st" = "operating" ] || die "reconfiguration did not complete (state=$st). Check: dmesg | tail"
    echo "OK: fabric configured from $RBF_DEST"
}

do_load() {
    local rbf="$1"
    [ -f "$rbf" ] || die "bitstream not found: $rbf"
    local sz; sz=$(stat -c %s "$rbf")
    if [ "$sz" -lt 3000000 ]; then
        echo "fpga-load: warning: '$rbf' is $sz bytes — looks COMPRESSED." >&2
        echo "           MSEL=00000 needs an uncompressed .rbf, or config times out (err=-110)." >&2
        echo "           Regenerate with:  quartus_cpf -c design.sof design.rbf" >&2
    fi
    ensure_configfs
    install -m 0644 "$rbf" "$RBF_DEST"    # your design -> /lib/firmware/fpga.rbf
    apply_staged
}

do_unload() {
    ensure_configfs
    if [ -d "$OVL_DIR" ]; then remove_overlay && echo "Overlay removed (region released)."; else echo "Nothing to remove."; fi
}

do_status() {
    ensure_configfs
    [ -r "$FPGA_STATE" ] && echo "FPGA manager state : $(cat "$FPGA_STATE")"
    if [ -d "$OVL_DIR" ]; then
        echo "Overlay '$OVERLAY_NAME'       : present (status: $(cat "$OVL_DIR/status" 2>/dev/null || echo unknown))"
    else
        echo "Overlay '$OVERLAY_NAME'       : not applied"
    fi
    [ -f "$RBF_DEST" ] && echo "Staged bitstream   : $RBF_DEST ($(stat -c %s "$RBF_DEST") bytes)"
}

case "${1:-}" in
    -a|--apply)  apply_staged ;;
    -u|--unload) do_unload ;;
    -s|--status) do_status ;;
    -h|--help|"") usage ;;
    -*)          die "unknown option: $1" ;;
    *)           do_load "$1" ;;
esac
