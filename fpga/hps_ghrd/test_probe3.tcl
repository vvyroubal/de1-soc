package require qsys
create_system {probe3}
set_project_property DEVICE_FAMILY {Cyclone V}
set_project_property DEVICE {5CSEMA5F31C6}
add_instance hps_0 altera_hps
set_instance_parameter_value hps_0 {HARD_EMIF} {0}
set_instance_parameter_value hps_0 {BOOTFROMFPGA_Enable} {0}
save_system {probe3.qsys}
