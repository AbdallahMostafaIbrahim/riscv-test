/*******************************************************************
*
* Module: mem_wb_reg.v
* Project: RISCV Processor
* Description: MEM/WB pipeline register. Carries the three writeback
*              candidates (ALU result, loaded data, pc+4) and the WB
*              control bits. No bubble: once an instruction reaches
*              MEM it is committed.
*
**********************************************************************/
`timescale 1ns / 1ps

module mem_wb_reg (
    input         clk,
    input         rst,

    input  [31:0] alu_out_in,
    input  [31:0] load_out_in,
    input  [31:0] pc_plus_4_in,
    input  [4:0]  rd_in,
    input  [1:0]  wb_src_in,
    input         c_reg_write_in,
    input         halt_in,

    output [31:0] alu_out,
    output [31:0] load_out,
    output [31:0] pc_plus_4,
    output [4:0]  rd,
    output [1:0]  wb_src,
    output        c_reg_write,
    output        halt
);

    register #(.N(32)) alu_out_r     (.clk(clk), .rst(rst), .load(1'b1), .d(alu_out_in),     .q(alu_out));
    register #(.N(32)) load_out_r    (.clk(clk), .rst(rst), .load(1'b1), .d(load_out_in),    .q(load_out));
    register #(.N(32)) pc_plus_4_r   (.clk(clk), .rst(rst), .load(1'b1), .d(pc_plus_4_in),   .q(pc_plus_4));
    register #(.N(5))  rd_r          (.clk(clk), .rst(rst), .load(1'b1), .d(rd_in),          .q(rd));
    register #(.N(2))  wb_src_r      (.clk(clk), .rst(rst), .load(1'b1), .d(wb_src_in),      .q(wb_src));
    register #(.N(1))  c_reg_write_r (.clk(clk), .rst(rst), .load(1'b1), .d(c_reg_write_in), .q(c_reg_write));
    register #(.N(1))  halt_r        (.clk(clk), .rst(rst), .load(1'b1), .d(halt_in),        .q(halt));

endmodule
