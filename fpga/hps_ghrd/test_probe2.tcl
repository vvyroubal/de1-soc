package require qsys
create_system {probe2}
set_project_property DEVICE_FAMILY {Cyclone V}
set_project_property DEVICE {5CSEMA5F31C6}
set_project_property BOARD {}
add_instance clk_0 clock_source
set_instance_parameter_value clk_0 {clockFrequency} {50000000.0}
save_system {probe2.qsys}
