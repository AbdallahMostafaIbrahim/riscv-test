/*******************************************************************
*
* Module: hazard_unit.v
* Project: riscv32Project
* Author: Arch Island
* Description: Hazard detection for the 5-stage pipeline. Produces
*              a single `stall` signal that covers two cases:
*
*              1) Load-use (data) hazard.
*                 The instruction in EX is a load and the instruction
*                 in ID reads that load's destination register.
*                 Stall the dependent inst one cycle so the load's
*                 result appears in MEM/WB and existing forwarding
*                 can deliver it.
*
*              2) Single-port memory structural hazard.
*                 The instruction in MEM is a load or store, so it
*                 is using the unified inst/data memory port. IF
*                 cannot fetch that cycle -- freeze fetch until MEM
*                 is done.
*
*              Downstream effect of stall (top module wires this):
*                - PC.load is gated off      -> PC holds.
*                - IF/ID.load is gated off   -> dependent / stalled
*                                               inst stays in ID.
*                - ID/EX input is replaced by zeros -> NOP bubble
*                                               flows into EX next
*                                               cycle so the frozen
*                                               inst doesn't execute
*                                               twice.
*
*              x0 is excluded from the load-use check -- a load
*              with rd = x0 writes nowhere, so no data hazard.
*
* Change history: 2026-04-23 - Initial load-use detection.
*                 2026-04-23 - Added mem_stall for the single-port
*                              memory structural hazard.
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
