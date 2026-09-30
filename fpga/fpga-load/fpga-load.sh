#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
#
# fpga-load.sh -- reconfigure the DE1-SoC FPGA fabric at runtime from HPS Linux.
#
# Works for any self-contained fabric design on the mainline (6.12) image. It
# applies a device-tree overlay to the base FPGA region naming a bitstream under
# /lib/firmware, so the FPGA Manager programs the fabric. Overlays are applied
# from userspace via the `dtbocfg` configfs module (mainline has no built-in
# userspace overlay interface).
#
# Usage (auto-elevates with sudo):
#   ./fpga-load.sh <design.rbf>       copy to /lib/firmware/fpga.rbf and load it
#   ./fpga-load.sh -l|--link <design.rbf>
#                                     point /lib/firmware/fpga.rbf at <design.rbf>
#                                     (symlink, no 7 MB copy) and load it
#   ./fpga-load.sh -n|--name <fw>     load /lib/firmware/<fw> as-is (needs dtc)
#   ./fpga-load.sh -a|--apply         load the already-staged /lib/firmware/fpga.rbf
#   ./fpga-load.sh -u|--unload        remove the overlay (release the region)
#   ./fpga-load.sh -s|--status        show overlay + FPGA-manager state
#
# fpga.rbf is the name fpga-overlay.service re-applies at boot, so -l and the
# plain <design.rbf> form persist across reboots (with the service enabled);
# -n does not.
#
# The .rbf MUST be uncompressed (MSEL=00000 / FPP). Generate with:
#   quartus_cpf -c -o bitstream_compression=off design.sof design.rbf
set -euo pipefail

OVERLAY_NAME="fpga"
FW_DIR="/lib/firmware"
DEFAULT_FW="fpga.rbf"
RBF_DEST="$FW_DIR/$DEFAULT_FW"
CONFIGFS="/sys/kernel/config"
OVL_DIR="$CONFIGFS/device-tree/overlays/$OVERLAY_NAME"
FPGA_STATE="/sys/class/fpga_manager/fpga0/state"
FW_RECORD="/run/fpga-load.fw"        # firmware name of the applied overlay

# Fallback for images without dtc (v2.0.1 and older): the overlay below
# (overlay_dts fpga.rbf == fpga_generic_overlay.dts), compiled. Regenerate with
#   dtc -I dts -O dtb fpga_generic_overlay.dts | base64 -w0
# Only usable for the default firmware name; any other name needs dtc.
DTBO_B64="0A3+7QAAAMYAAAA4AAAArAAAACgAAAARAAAAEAAAAAAAAAAaAAAAdAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAFmcmFnbWVudEAwAAAAAAADAAAAFgAAAAAvc29jL2Jhc2VfZnBnYV9yZWdpb24AAAAAAAABX19vdmVybGF5X18AAAAAAwAAAAkAAAAMZnBnYS5yYmYAAAAAAAAAAgAAAAIAAAACAAAACXRhcmdldC1wYXRoAGZpcm13YXJlLW5hbWUA"

die() { echo "fpga-load: error: $*" >&2; exit 1; }
usage() {
    echo "Usage: $0 <design.rbf> | -l|--link <design.rbf> | -n|--name <fw>"
    echo "          | -a|--apply | -u|--unload | -s|--status"
}

[ "$(id -u)" -eq 0 ] || exec sudo -- "$0" "$@"

ensure_overlays() {
    modprobe dtbocfg 2>/dev/null || true          # provides configfs overlays iface
    [ -d "$CONFIGFS/device-tree" ] || mount -t configfs none "$CONFIGFS" 2>/dev/null || true
    [ -d "$CONFIGFS/device-tree/overlays" ] \
        || die "no configfs overlays dir — is the dtbocfg module present? (modprobe dtbocfg)"
}

remove_overlay() { [ -d "$OVL_DIR" ] && rmdir "$OVL_DIR" || true; rm -f "$FW_RECORD"; }

# The kernel resolves firmware-name relative to /lib/firmware; subdirectories
# are fine, absolute paths and '..' are not. The name is also spliced into the
# overlay source, so allow only characters that need no DTS escaping.
check_fw_name() {
    local fw="$1"
    [[ "$fw" =~ ^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$ ]] \
        || die "invalid firmware name '$fw' (relative to $FW_DIR; letters, digits, . _ + - /)"
    [[ "/$fw/" != */../* ]] || die "firmware name must not contain '..': $fw"
}

# Warn if a bitstream looks compressed (uncompressed Cyclone V .rbf is ~7 MB).
check_rbf_size() {
    local sz; sz=$(stat -L -c %s "$1")
    [ "$sz" -ge 3000000 ] || echo "fpga-load: warning: '$1' is $sz bytes — looks COMPRESSED;" \
        "MSEL=00000 needs an uncompressed .rbf (quartus_cpf -o bitstream_compression=off)." >&2
}

# Overlay source; mirrors fpga_generic_overlay.dts with a variable firmware-name.
overlay_dts() {
    cat <<EOF
/dts-v1/;
/plugin/;

/ {
    fragment@0 {
        target-path = "/soc/base_fpga_region";
        __overlay__ {
            firmware-name = "$1";
        };
    };
};
EOF
}

# Write the compiled overlay naming firmware $1 to stdout.
make_dtbo() {
    if command -v dtc >/dev/null; then
        overlay_dts "$1" | dtc -q -I dts -O dtb -
    elif [ "$1" = "$DEFAULT_FW" ]; then
        base64 -d <<<"$DTBO_B64"
    else
        die "loading '$1' by name needs dtc (sudo apt install device-tree-compiler);" \
            "or use: $0 --link $FW_DIR/$1"
    fi
}

# Apply the overlay naming /lib/firmware/$1 (default fpga.rbf).
apply_fw() {
    local fw="${1:-$DEFAULT_FW}"
    check_fw_name "$fw"
    ensure_overlays
    if [ ! -f "$FW_DIR/$fw" ]; then
        [ "$fw" = "$DEFAULT_FW" ] && die "no bitstream at $FW_DIR/$fw — run '$0 <design.rbf>' first"
        die "no bitstream at $FW_DIR/$fw — copy your uncompressed .rbf there first"
    fi
    local dtbo; dtbo=$(make_dtbo "$fw" | base64 -w0) || exit 1
    [ -n "$dtbo" ] || die "overlay compile produced no output"
    remove_overlay
    mkdir "$OVL_DIR"
    # Two steps with dtbocfg: (1) load the compiled overlay blob into the 'dtbo'
    # attribute — this only STORES it; (2) write 1 to 'status' to actually APPLY
    # it (dtbocfg_overlay_item_status_store -> of_overlay_fdt_apply), which is
    # what fires the fpga-region notifier and reprograms the fabric. Writing dtbo
    # alone is a silent no-op: the blob is stored, status stays 0, nothing
    # reprograms, and the FPGA manager keeps reporting the previous ('operating')
    # state — which is exactly the trap that made this look like it worked.
    if ! base64 -d <<<"$dtbo" > "$OVL_DIR/dtbo" 2>/dev/null; then
        remove_overlay; die "overlay load failed — check: dmesg | tail"
    fi
    if ! echo 1 > "$OVL_DIR/status" 2>/dev/null; then
        remove_overlay; die "overlay apply (status=1) failed — check: dmesg | tail"
    fi
    # Confirm dtbocfg actually applied it (status reads back 1); a 0 here means
    # the reconfiguration silently did not happen.
    [ "$(cat "$OVL_DIR/status" 2>/dev/null)" = "1" ] \
        || { remove_overlay; die "overlay did not apply (status!=1). Check: dmesg | tail"; }
    echo "$fw" > "$FW_RECORD"
    sleep 1
    local st; st=$(cat "$FPGA_STATE" 2>/dev/null || echo unknown)
    echo "FPGA manager state : $st"
    [ "$st" = "operating" ] || { remove_overlay; die "reconfig did not complete (state=$st). Check: dmesg | tail"; }
    echo "OK: fabric configured from $FW_DIR/$fw"
}

do_load() {
    local rbf="$1"; [ -f "$rbf" ] || die "bitstream not found: $rbf"
    check_rbf_size "$rbf"
    mkdir -p "$FW_DIR"                     # minimal rootfs may lack /lib/firmware
    rm -f "$RBF_DEST"                      # may be a symlink left by --link
    install -m 0644 "$rbf" "$RBF_DEST"
    apply_fw
}

do_link() {
    local rbf="${1:-}"; [ -n "$rbf" ] || die "--link needs a bitstream path"
    [ -f "$rbf" ] || die "bitstream not found: $rbf"
    rbf=$(readlink -f "$rbf")
    [ "$rbf" != "$(readlink -f "$RBF_DEST")" ] || die "$rbf is $RBF_DEST itself — use --apply"
    check_rbf_size "$rbf"
    mkdir -p "$FW_DIR"
    ln -sfn "$rbf" "$RBF_DEST"
    echo "Linked $RBF_DEST -> $rbf"
    apply_fw
}

do_status() {
    ensure_overlays
    [ -r "$FPGA_STATE" ] && echo "FPGA manager state : $(cat "$FPGA_STATE")"
    if [ -d "$OVL_DIR" ]; then
        echo "Overlay '$OVERLAY_NAME'      : applied ($(f=$(cat "$FW_RECORD" 2>/dev/null) && echo "$FW_DIR/$f" || echo 'firmware unknown'))"
    else
        echo "Overlay '$OVERLAY_NAME'      : not applied"
    fi
    if [ -L "$RBF_DEST" ]; then
        echo "Staged bitstream   : $RBF_DEST -> $(readlink "$RBF_DEST")"
    elif [ -f "$RBF_DEST" ]; then
        echo "Staged bitstream   : $RBF_DEST ($(stat -c %s "$RBF_DEST") bytes)"
    fi
    command -v dtc >/dev/null && echo "Overlay compiler   : dtc" \
        || echo "Overlay compiler   : none (embedded fpga.rbf overlay only)"
}

case "${1:-}" in
    -a|--apply)  apply_fw ;;
    -l|--link)   do_link "${2:-}" ;;
    -n|--name)   [ -n "${2:-}" ] || die "--name needs a firmware name"; apply_fw "$2" ;;
    -u|--unload) ensure_overlays; remove_overlay; echo "Overlay removed (region released)." ;;
    -s|--status) do_status ;;
    -h|--help|"") usage ;;
    -*)          die "unknown option: $1" ;;
    *)           do_load "$1" ;;
esac
