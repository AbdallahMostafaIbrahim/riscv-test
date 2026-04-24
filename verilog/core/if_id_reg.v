/*******************************************************************
*
* Module: if_id_reg.v
* Project: RISCV Processor
* Description: IF/ID pipeline register. Packs the IF-stage outputs
*              (pc, pc_plus_4, inst, predicted_taken) and latches
*              them. bubble zeros the input on a branch flush; load=0
*              freezes the register on a load-use stall or when a
*              halt is in flight.
*
**********************************************************************/
`timescale 1ns / 1ps

module if_id_reg (
    input         clk,
    input         rst,
    input         load,
    input         bubble,

    input  [31:0] pc_in,
    input  [31:0] pc_plus_4_in,
    input  [31:0] inst_in,
    input         predicted_taken_in,

    output [31:0] pc,
    output [31:0] pc_plus_4,
    output [31:0] inst,
    output        predicted_taken
);

    localparam N = 97;

    wire [N-1:0] d_fresh;
    wire [N-1:0] d;
    wire [N-1:0] q;

    assign d_fresh = { predicted_taken_in, inst_in, pc_plus_4_in, pc_in };
    assign d       = bubble ? {N{1'b0}} : d_fresh;

    register #(.N(N)) r (
        .clk (clk),
        .rst (rst),
        .load(load),
        .d   (d),
        .q   (q)
    );

    assign pc              = q[31:0];
    assign pc_plus_4       = q[63:32];
    assign inst            = q[95:64];
    assign predicted_taken = q[96];

endmodule
