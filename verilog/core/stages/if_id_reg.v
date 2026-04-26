/*******************************************************************
*
* Module: if_id_reg.v
* Project: RISCV Processor
* Description: IF/ID pipeline register. stores pc, pc_plus_4, inst
*              and the predicted-taken bit. bubble zeros the input
*              on flush, load=0 freezes on stall or halt.
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

    wire [31:0] pc_d              = bubble ? 32'b0 : pc_in;
    wire [31:0] pc_plus_4_d       = bubble ? 32'b0 : pc_plus_4_in;
    wire [31:0] inst_d            = bubble ? 32'b0 : inst_in;
    wire        predicted_taken_d = bubble ? 1'b0  : predicted_taken_in;

    register #(.N(32)) pc_r              (.clk(clk), .rst(rst), .load(load), .d(pc_d),              .q(pc));
    register #(.N(32)) pc_plus_4_r       (.clk(clk), .rst(rst), .load(load), .d(pc_plus_4_d),       .q(pc_plus_4));
    register #(.N(32)) inst_r            (.clk(clk), .rst(rst), .load(load), .d(inst_d),            .q(inst));
    register #(.N(1))  predicted_taken_r (.clk(clk), .rst(rst), .load(load), .d(predicted_taken_d), .q(predicted_taken));

endmodule
