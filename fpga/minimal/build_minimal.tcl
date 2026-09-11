package require ::quartus::project
package require ::quartus::flow

set PROJECT "minimal"
set DEVICE  "5CSEMA5F31C6"
set TOP     "minimal_top"

if {[project_exists $PROJECT]} {
    project_open $PROJECT
} else {
    project_new $PROJECT
}

set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE $DEVICE
set_global_assignment -name TOP_LEVEL_ENTITY $TOP
set_global_assignment -name VERILOG_FILE minimal_top.v

# No pin assignments - no I/O used at all.
set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 256

execute_flow -compile

project_close
