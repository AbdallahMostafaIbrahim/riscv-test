# Generate a Vivado project for riscv32Project.
#
# Usage (from the repo root):
#   vivado -mode batch -source vivado_project.tcl
#
# Or from the Vivado Tcl console:
#   cd <repo-root>; source vivado_project.tcl

set proj_name   "riscv32Project"
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
add_files -fileset sources_1 -norecurse [glob verilog/primitives/*.v \
                                              verilog/core/*.v \
                                              verilog/core/stages/*.v \
                                              verilog/memory/*.v]

# defines.v is `included by other modules; mark it as a header and add the
# include path so Vivado resolves `include "defines.v"` (mirrors iverilog -I).
set_property file_type "Verilog Header" \
    [get_files verilog/core/defines.v]
set_property include_dirs [list [file normalize verilog/core]] \
    [get_filesets sources_1]

set_property top riscv [get_filesets sources_1]

# ----- Simulation sources --------------------------------------------------
# Pick up every *_tb.v under test/test_benches/. Add new tests by dropping
# another test/test_benches/<name>_tb.v and re-sourcing this script.
add_files -fileset sim_1 -norecurse [glob test/test_benches/*_tb.v]
set_property include_dirs [list [file normalize verilog/core]] \
    [get_filesets sim_1]

# Memory init: testbenches read inst.hex from the xsim cwd. Marking it as a
# Memory Initialization File makes Vivado copy it into the sim run dir so
# $readmemh("inst.hex") resolves at runtime.
add_files -fileset sim_1 -norecurse [list test/mem/inst.hex]
set_property file_type "Memory Initialization Files" \
    [get_files test/mem/inst.hex]

# Default sim top is the dump testbench; switch via run_prog -tb <name>.
set_property top dump_tb [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project created at [file normalize $proj_dir/$proj_name.xpr]"
