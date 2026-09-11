package require qsys
load_system {de1_soc.qsys}

set_instance_parameter_value hps_0 {HARD_EMIF} {0}
set_instance_parameter_value hps_0 {EMAC1_PinMuxing} {Unused}
set_instance_parameter_value hps_0 {EMAC1_Mode} {N/A}
set_instance_parameter_value hps_0 {QSPI_PinMuxing} {Unused}
set_instance_parameter_value hps_0 {QSPI_Mode} {N/A}
set_instance_parameter_value hps_0 {SPIM1_PinMuxing} {Unused}
set_instance_parameter_value hps_0 {SPIM1_Mode} {N/A}
set_instance_parameter_value hps_0 {USB1_PinMuxing} {Unused}
set_instance_parameter_value hps_0 {USB1_Mode} {N/A}
set_instance_parameter_value hps_0 {I2C0_PinMuxing} {Unused}
set_instance_parameter_value hps_0 {I2C0_Mode} {N/A}
set_instance_parameter_value hps_0 {I2C1_PinMuxing} {Unused}
set_instance_parameter_value hps_0 {I2C1_Mode} {N/A}
set_instance_parameter_value hps_0 {GPIO_Enable} {No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No No}

save_system {de1_soc.qsys}
