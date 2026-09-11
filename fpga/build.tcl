# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Vedran Vyroubal, Veleuciliste u Karlovcu (VUKA)
package require ::quartus::project
package require ::quartus::flow

set PROJECT "de1soc_blinker"
set DEVICE  "5CSEMA5F31C6"
set TOP     "de1soc_top"

# Create or open project
if {[project_exists $PROJECT]} {
    project_open $PROJECT
} else {
    project_new $PROJECT
}

# Device and family
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE $DEVICE
set_global_assignment -name TOP_LEVEL_ENTITY $TOP

# Source files
set_global_assignment -name VERILOG_FILE rtl/de1soc_top.v

# Pin assignments
source constraints/de1soc_pins.tcl

# Timing
set_global_assignment -name TIMING_ANALYZER_MULTICORNER_ANALYSIS ON
set_global_assignment -name SDC_FILE constraints/de1soc_timing.sdc

# Compilation settings
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 256

# Full compilation (project must remain open)
execute_flow -compile

project_close
