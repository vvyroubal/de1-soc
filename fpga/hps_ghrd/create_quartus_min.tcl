project_new -overwrite -family CYCLONEV -part 5CSEMA5F31C6 de1_soc_top_min

set_global_assignment -name TOP_LEVEL_ENTITY de1_soc_top_min
set_global_assignment -name QIP_FILE de1_soc/synthesis/de1_soc.qip
set_global_assignment -name VHDL_FILE de1_soc_top_min.vhd

set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files_min
set_global_assignment -name EDA_SIMULATION_TOOL "<None>"
set_global_assignment -name EDA_OUTPUT_DATA_FORMAT NONE -section_id eda_simulation

source pin_assignment_de1_soc_top.tcl

project_close
