/*******************************************************************
*
* Module: hazard_unit.v
* Project: riscv32Project
* Author: Arch Island
* Description: Hazard detection produces a `stall` signal that covers both:
*              Load-use data hazard and single-port memory structural hazard.
*
**********************************************************************/
`timescale 1ns / 1ps

module hazard_unit (
    input  [4:0] id_ex_rd,
    input        id_ex_mem_read,
    input  [4:0] if_id_rs1,
    input  [4:0] if_id_rs2,
    input        ex_mem_mem_read,
    input        ex_mem_mem_write,
    output       stall
);

    wire load_use_stall;
    wire mem_stall;

    assign load_use_stall = id_ex_mem_read
                          & (id_ex_rd != 5'b0)
                          & ( (id_ex_rd == if_id_rs1)
                            | (id_ex_rd == if_id_rs2) );

    assign mem_stall = ex_mem_mem_read | ex_mem_mem_write;

    assign stall = load_use_stall | mem_stall;

endmodule
