#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
# Program the DE1-SoC FPGA over JTAG (USB-Blaster II, the board's JTAG USB port).
# Build the .sof first:  quartus_sh -t build.tcl   (produces de1soc_blinker.sof)
#
# Uses quartus_pgm/jtagconfig from PATH; override the tool dir with
#   QUARTUS=/opt/altera_lite/<ver>/quartus/bin ./program.sh
QUARTUS="${QUARTUS:-}"
pgm() { "${QUARTUS:+$QUARTUS/}$1" "${@:2}"; }
SOF="${SOF:-$(dirname "$0")/de1soc_blinker.sof}"

[ -f "$SOF" ] || { echo "missing $SOF — build it first: quartus_sh -t build.tcl"; exit 1; }

echo "Detecting JTAG hardware..."
pgm jtagconfig

echo ""
echo "Programming FPGA..."
pgm quartus_pgm \
    --no_banner \
    --mode=JTAG \
    -o "P;${SOF}@1"

echo ""
echo "Done. LEDR[9:5] should now be blinking and HEX displays counting."
