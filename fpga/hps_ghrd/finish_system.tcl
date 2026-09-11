package require qsys

# Load the existing, GUI-validated system (hps_0 already correctly instantiated)
load_system {de1_soc.qsys}

# Add 50MHz clock source
add_instance clk_0 clock_source
set_instance_parameter_value clk_0 {clockFrequency} {50000000.0}
set_instance_parameter_value clk_0 {clockFrequencyKnown} {1}
set_instance_parameter_value clk_0 {resetSynchronousEdges} {NONE}

# Connect clocks
add_connection clk_0.clk hps_0.f2h_sdram0_clock
add_connection clk_0.clk hps_0.h2f_axi_clock
add_connection clk_0.clk hps_0.f2h_axi_clock
add_connection clk_0.clk hps_0.h2f_lw_axi_clock

# Peripheral pin muxing - match DE1-SoC physical wiring for SD card + UART0
set_instance_parameter_value hps_0 {SDIO_PinMuxing} {HPS I/O Set 0}
set_instance_parameter_value hps_0 {SDIO_Mode} {4-bit Data}
set_instance_parameter_value hps_0 {UART0_PinMuxing} {HPS I/O Set 0}
set_instance_parameter_value hps_0 {UART0_Mode} {No Flow Control}

# Export interfaces needed at the top level
add_interface clk clock sink
set_interface_property clk EXPORT_OF clk_0.clk_in
add_interface reset reset sink
set_interface_property reset EXPORT_OF clk_0.clk_in_reset
add_interface hps_0_h2f_reset reset source
set_interface_property hps_0_h2f_reset EXPORT_OF hps_0.h2f_reset

save_system {de1_soc.qsys}
