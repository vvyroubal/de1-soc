package require qsys
load_system {de1_soc.qsys}
set_instance_parameter_value hps_0 {HARD_EMIF} {1}
save_system {de1_soc.qsys}
