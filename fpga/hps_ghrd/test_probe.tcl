package require qsys
create_system {probe}
set_project_property DEVICE_FAMILY {Cyclone V}
set_project_property DEVICE {5CSEMA5F31C6}
add_instance clk_0 clock_source
add_instance hps_0 altera_hps
save_system {probe.qsys}
