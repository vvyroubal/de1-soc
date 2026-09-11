package require ::quartus::project
package require ::quartus::flow

project_open de1_soc_top_v2

execute_module -tool map
source de1_soc/synthesis/submodules/hps_sdram_p0_pin_assignments.tcl
execute_module -tool fit
execute_module -tool asm
execute_module -tool sta

project_close
