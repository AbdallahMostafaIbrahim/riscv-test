/*******************************************************************
*
* Module: id_ex_reg.v
* Project: RISCV Processor
* Description: ID/EX pipeline register. Latches operands, immediate
*              and controls for EX. bubble zeros every field on a
*              load-use stall or a branch flush so no wrong-path
*              instruction enters EX.
*
**********************************************************************/
`timescale 1ns / 1ps

module id_ex_reg (
    input         clk,
    input         rst,
    input         bubble,

    input  [31:0] pc_in,
    input  [31:0] pc_plus_4_in,
    input  [31:0] rs1_data_in,
    input  [31:0] rs2_data_in,
    input  [31:0] imm_in,
    input  [4:0]  rd_in,
    input  [4:0]  rs1_in,
    input  [4:0]  rs2_in,
    input  [2:0]  funct3_in,
    input  [3:0]  alu_sel_in,
    input  [1:0]  alu_src_a_in,
    input         alu_src_b_in,
    input         c_branch_in,
    input         c_jump_in,
    input         c_jalr_in,
    input         c_mem_read_in,
    input         c_mem_write_in,
    input  [1:0]  wb_src_in,
    input         c_reg_write_in,
    input         halt_in,
    input         predicted_taken_in,

    output [31:0] pc,
    output [31:0] pc_plus_4,
    output [31:0] rs1_data,
    output [31:0] rs2_data,
    output [31:0] imm,
    output [4:0]  rd,
    output [4:0]  rs1,
    output [4:0]  rs2,
    output [2:0]  funct3,
    output [3:0]  alu_sel,
    output [1:0]  alu_src_a,
    output        alu_src_b,
    output        c_branch,
    output        c_jump,
    output        c_jalr,
    output        c_mem_read,
    output        c_mem_write,
    output [1:0]  wb_src,
    output        c_reg_write,
    output        halt,
    output        predicted_taken
);

    wire [31:0] pc_d              = bubble ? 32'b0 : pc_in;
    wire [31:0] pc_plus_4_d       = bubble ? 32'b0 : pc_plus_4_in;
    wire [31:0] rs1_data_d        = bubble ? 32'b0 : rs1_data_in;
    wire [31:0] rs2_data_d        = bubble ? 32'b0 : rs2_data_in;
    wire [31:0] imm_d             = bubble ? 32'b0 : imm_in;
    wire [4:0]  rd_d              = bubble ? 5'b0  : rd_in;
    wire [4:0]  rs1_d             = bubble ? 5'b0  : rs1_in;
    wire [4:0]  rs2_d             = bubble ? 5'b0  : rs2_in;
    wire [2:0]  funct3_d          = bubble ? 3'b0  : funct3_in;
    wire [3:0]  alu_sel_d         = bubble ? 4'b0  : alu_sel_in;
    wire [1:0]  alu_src_a_d       = bubble ? 2'b0  : alu_src_a_in;
    wire        alu_src_b_d       = bubble ? 1'b0  : alu_src_b_in;
    wire        c_branch_d        = bubble ? 1'b0  : c_branch_in;
    wire        c_jump_d          = bubble ? 1'b0  : c_jump_in;
    wire        c_jalr_d          = bubble ? 1'b0  : c_jalr_in;
    wire        c_mem_read_d      = bubble ? 1'b0  : c_mem_read_in;
    wire        c_mem_write_d     = bubble ? 1'b0  : c_mem_write_in;
    wire [1:0]  wb_src_d          = bubble ? 2'b0  : wb_src_in;
    wire        c_reg_write_d     = bubble ? 1'b0  : c_reg_write_in;
    wire        halt_d            = bubble ? 1'b0  : halt_in;
    wire        predicted_taken_d = bubble ? 1'b0  : predicted_taken_in;

    register #(.N(32)) pc_r              (.clk(clk), .rst(rst), .load(1'b1), .d(pc_d),              .q(pc));
    register #(.N(32)) pc_plus_4_r       (.clk(clk), .rst(rst), .load(1'b1), .d(pc_plus_4_d),       .q(pc_plus_4));
    register #(.N(32)) rs1_data_r        (.clk(clk), .rst(rst), .load(1'b1), .d(rs1_data_d),        .q(rs1_data));
    register #(.N(32)) rs2_data_r        (.clk(clk), .rst(rst), .load(1'b1), .d(rs2_data_d),        .q(rs2_data));
    register #(.N(32)) imm_r             (.clk(clk), .rst(rst), .load(1'b1), .d(imm_d),             .q(imm));
    register #(.N(5))  rd_r              (.clk(clk), .rst(rst), .load(1'b1), .d(rd_d),              .q(rd));
    register #(.N(5))  rs1_r             (.clk(clk), .rst(rst), .load(1'b1), .d(rs1_d),             .q(rs1));
    register #(.N(5))  rs2_r             (.clk(clk), .rst(rst), .load(1'b1), .d(rs2_d),             .q(rs2));
    register #(.N(3))  funct3_r          (.clk(clk), .rst(rst), .load(1'b1), .d(funct3_d),          .q(funct3));
    register #(.N(4))  alu_sel_r         (.clk(clk), .rst(rst), .load(1'b1), .d(alu_sel_d),         .q(alu_sel));
    register #(.N(2))  alu_src_a_r       (.clk(clk), .rst(rst), .load(1'b1), .d(alu_src_a_d),       .q(alu_src_a));
    register #(.N(1))  alu_src_b_r       (.clk(clk), .rst(rst), .load(1'b1), .d(alu_src_b_d),       .q(alu_src_b));
    register #(.N(1))  c_branch_r        (.clk(clk), .rst(rst), .load(1'b1), .d(c_branch_d),        .q(c_branch));
    register #(.N(1))  c_jump_r          (.clk(clk), .rst(rst), .load(1'b1), .d(c_jump_d),          .q(c_jump));
    register #(.N(1))  c_jalr_r          (.clk(clk), .rst(rst), .load(1'b1), .d(c_jalr_d),          .q(c_jalr));
    register #(.N(1))  c_mem_read_r      (.clk(clk), .rst(rst), .load(1'b1), .d(c_mem_read_d),      .q(c_mem_read));
    register #(.N(1))  c_mem_write_r     (.clk(clk), .rst(rst), .load(1'b1), .d(c_mem_write_d),     .q(c_mem_write));
    register #(.N(2))  wb_src_r          (.clk(clk), .rst(rst), .load(1'b1), .d(wb_src_d),          .q(wb_src));
    register #(.N(1))  c_reg_write_r     (.clk(clk), .rst(rst), .load(1'b1), .d(c_reg_write_d),     .q(c_reg_write));
    register #(.N(1))  halt_r            (.clk(clk), .rst(rst), .load(1'b1), .d(halt_d),            .q(halt));
    register #(.N(1))  predicted_taken_r (.clk(clk), .rst(rst), .load(1'b1), .d(predicted_taken_d), .q(predicted_taken));

endmodule
