# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
# Timing constraints: the DE1-SoC 50 MHz oscillator. Quartus picks up
# <revision>.sdc automatically; without it, it assumes a 1 GHz clock and
# reports "Timing requirements not met".
create_clock -name {CLOCK_50} -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty
