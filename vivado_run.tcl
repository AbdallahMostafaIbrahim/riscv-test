# Helper procs for running riscv32Project programs from the Vivado Tcl Console.
#
# Source once per session (from the project root):
#     source vivado_run.tcl
#
# Then in the Tcl Console:
#     run_prog fibonacci                   ; # assembles + runs dump_tb
#     run_prog forward    -tb forward_tb   ; # run the forward testbench
#     run_prog b-type     -tb b-type_tb    ; # run the b-type regression

proc run_prog {name args} {
    # Default testbench is dump_tb. Override with -tb <name>.
    set tb "dump_tb"
    for {set i 0} {$i < [llength $args]} {incr i} {
        set a [lindex $args $i]
        if {$a eq "-tb"} {
            incr i
            set tb [lindex $args $i]
        } else {
            puts "ignoring unknown option: $a"
        }
    }

    set repo_root [file normalize [file dirname [info script]]]
    set src "$repo_root/test/asm/$name.s"
    set dst "$repo_root/test/mem/inst.hex"

    if {![file exists $src]} {
        puts "ERROR: $src not found"
        return
    }

    puts "assembling $src -> $dst"
    exec python3 "$repo_root/tools/asm.py" $src $dst

    puts "setting sim top = $tb"
    set_property top $tb [get_filesets sim_1]

    if {[llength [get_objects -quiet]] > 0} {
        # A simulation is already running; relaunch to pick up the new
        # hex and possibly the new top.
        relaunch_sim
    } else {
        launch_simulation
    }
    run all
}
