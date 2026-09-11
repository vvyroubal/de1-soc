package require ::quartus::project
package require ::quartus::flow

project_open de1_soc_top_fixed

# Analysis & Synthesis first
execute_module -tool map

# DDR3 PHY pin/IO-standard/OCT assignments - must run after synthesis, before fitting
source de1_soc/synthesis/submodules/hps_sdram_p0_pin_assignments.tcl

# Fitter, Assembler, Timing Analysis
execute_module -tool fit
execute_module -tool asm
execute_module -tool sta

project_close
