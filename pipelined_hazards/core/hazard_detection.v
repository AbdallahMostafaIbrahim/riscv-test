`timescale 1ns / 1ps

// Load-use hazard detector. Raises stall for one cycle when the
// instruction currently in ID reads a register that the load in EX
// will produce (too late for forwarding).
module hazard_detection (
    input  [4:0] if_id_rs1,
    input  [4:0] if_id_rs2,
    input  [4:0] id_ex_rd,
    input        id_ex_mem_read,
    output       stall
);

    assign stall = id_ex_mem_read && (id_ex_rd != 5'b0) &&
                   ((if_id_rs1 == id_ex_rd) || (if_id_rs2 == id_ex_rd));

endmodule
