# Generate a Vivado project for femtoRV32.
#
# Usage (from the repo root):
#   vivado -mode batch -source vivado_project.tcl
#
# Or from the Vivado Tcl console:
#   cd <repo-root>; source vivado_project.tcl

set proj_name   "femtorv32"
set proj_dir    "./vivado"
set part_name   "xc7a100tcsg324-1"   ;# Nexys A7-100T; use xc7a50tcsg324-1 for 50T
set board_part  "digilentinc.com:nexys-a7-100t:part0:1.2"

file mkdir $proj_dir
create_project -force $proj_name $proj_dir -part $part_name

# Attach the Nexys A7 board preset if it is installed locally.
if {[catch {set_property board_part $board_part [current_project]} err]} {
    puts "WARNING: board preset '$board_part' not found; continuing without it."
}

# ----- Design sources ------------------------------------------------------
add_files -fileset sources_1 -norecurse [glob rtl/primitives/*.v \
                                              rtl/core/*.v \
                                              rtl/memory/*.v]
set_property top riscv [get_filesets sources_1]

# ----- Simulation sources --------------------------------------------------
# Pick up every *_tb.v in test/. Add new tests by dropping another
# test/<name>_tb.v and re-sourcing this script (or `add_files` the new
# one by hand).
add_files -fileset sim_1 -norecurse [glob test/*_tb.v]

# Memory init files -- added by reference so edits in the repo are
# picked up the next time the sim is launched. The file_type property
# makes Vivado copy them into the xsim working dir at sim time so
# $readmemh("inst.hex") / $readmemh("data.hex") resolve correctly.
add_files -fileset sim_1 -norecurse [list mem/inst.hex mem/data.hex]
set_property file_type "Memory Initialization Files" \
    [get_files mem/inst.hex]
set_property file_type "Memory Initialization Files" \
    [get_files mem/data.hex]

set_property top riscv_tb [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project created at [file normalize $proj_dir/$proj_name.xpr]"
