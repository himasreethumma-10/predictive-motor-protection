# Add missing RTL sources to the checked-in Vivado project after extraction.
# From Vivado's Tcl Console, run:
#   source /path/to/extracted/repo/vivado_add_sources.tcl

set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir Project_simulation_1.xpr]

if {[llength [current_project -quiet]] == 0} {
    if {![file exists $project_file]} {
        error "Vivado project not found: $project_file"
    }
    open_project $project_file
}

set rtl_files [list \
    [file join $script_dir current_deglitcher.v] \
    [file join $script_dir fast_trip_detector.v] \
    [file join $script_dir inverse_time_protection.v] \
]

foreach rtl_file $rtl_files {
    if {![file exists $rtl_file]} {
        error "Required RTL source not found: $rtl_file"
    }
    if {[llength [get_files -quiet -all $rtl_file]] == 0} {
        add_files -norecurse -fileset sources_1 $rtl_file
    }
}

# The checked-in testbench is disabled in the original project metadata.
# Re-enable it and make it the simulation top so the project can be simulated.
set tb_file [file join $script_dir tb_motor_protection_top.v]
if {![file exists $tb_file]} {
    error "Testbench not found: $tb_file"
}
set tb_objects [get_files -quiet -all $tb_file]
if {[llength $tb_objects] == 0} {
    add_files -norecurse -fileset sim_1 $tb_file
    set tb_objects [get_files -quiet -all $tb_file]
}
set_property used_in_simulation true $tb_objects
set_property top tb_motor_protection_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set_property top motor_protection_top [get_filesets sources_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "RTL sources registered. Save the project, then run behavioral simulation with:"
puts "  launch_simulation -simset sim_1 -mode behavioral"
puts "  run all"
