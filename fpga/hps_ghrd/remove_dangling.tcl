package require qsys
load_system {de1_soc.qsys}
remove_connection clk_0.clk hps_0.f2h_sdram0_clock
save_system {de1_soc.qsys}
