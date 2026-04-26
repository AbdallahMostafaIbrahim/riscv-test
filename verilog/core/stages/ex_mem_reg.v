/*******************************************************************
*
* Module: ex_mem_reg.v
* Project: RISCV Processor
* Description: EX/MEM pipeline register. Carries the ALU result, rs2
*              data (for stores), PC arithmetic, ALU flags, and the
*              control bits MEM uses to resolve the branch. bubble
*              zeros everything on flush so wrong-path writes never
*              reach mem or the reg file.
*
**********************************************************************/
`timescale 1ns / 1ps

module ex_mem_reg (
    input         clk,
    input         rst,
    input         bubble,

    input  [31:0] pc_in,
    input  [31:0] alu_out_in,
    input  [31:0] rs2_data_in,
    input  [31:0] pc_plus_4_in,
    input  [31:0] pc_plus_imm_in,
    input  [4:0]  rd_in,
    input  [2:0]  funct3_in,
    input         c_mem_read_in,
    input         c_mem_write_in,
    input  [1:0]  wb_src_in,
    input         c_reg_write_in,
    input         halt_in,
    input         c_branch_in,
    input         c_jump_in,
    input         c_jalr_in,
    input         flag_z_in,
    input         flag_c_in,
    input         flag_v_in,
    input         flag_n_in,
    input         predicted_taken_in,

    output [31:0] pc,
    output [31:0] alu_out,
    output [31:0] rs2_data,
    output [31:0] pc_plus_4,
    output [31:0] pc_plus_imm,
    output [4:0]  rd,
    output [2:0]  funct3,
    output        c_mem_read,
    output        c_mem_write,
    output [1:0]  wb_src,
    output        c_reg_write,
    output        halt,
    output        c_branch,
    output        c_jump,
    output        c_jalr,
    output        flag_z,
    output        flag_c,
    output        flag_v,
    output        flag_n,
    output        predicted_taken
);

    wire [31:0] pc_d              = bubble ? 32'b0 : pc_in;
    wire [31:0] alu_out_d         = bubble ? 32'b0 : alu_out_in;
    wire [31:0] rs2_data_d        = bubble ? 32'b0 : rs2_data_in;
    wire [31:0] pc_plus_4_d       = bubble ? 32'b0 : pc_plus_4_in;
    wire [31:0] pc_plus_imm_d     = bubble ? 32'b0 : pc_plus_imm_in;
    wire [4:0]  rd_d              = bubble ? 5'b0  : rd_in;
    wire [2:0]  funct3_d          = bubble ? 3'b0  : funct3_in;
    wire        c_mem_read_d      = bubble ? 1'b0  : c_mem_read_in;
    wire        c_mem_write_d     = bubble ? 1'b0  : c_mem_write_in;
    wire [1:0]  wb_src_d          = bubble ? 2'b0  : wb_src_in;
    wire        c_reg_write_d     = bubble ? 1'b0  : c_reg_write_in;
    wire        halt_d            = bubble ? 1'b0  : halt_in;
    wire        c_branch_d        = bubble ? 1'b0  : c_branch_in;
    wire        c_jump_d          = bubble ? 1'b0  : c_jump_in;
    wire        c_jalr_d          = bubble ? 1'b0  : c_jalr_in;
    wire        flag_z_d          = bubble ? 1'b0  : flag_z_in;
    wire        flag_c_d          = bubble ? 1'b0  : flag_c_in;
    wire        flag_v_d          = bubble ? 1'b0  : flag_v_in;
    wire        flag_n_d          = bubble ? 1'b0  : flag_n_in;
    wire        predicted_taken_d = bubble ? 1'b0  : predicted_taken_in;

    register #(.N(32)) pc_r              (.clk(clk), .rst(rst), .load(1'b1), .d(pc_d),              .q(pc));
    register #(.N(32)) alu_out_r         (.clk(clk), .rst(rst), .load(1'b1), .d(alu_out_d),         .q(alu_out));
    register #(.N(32)) rs2_data_r        (.clk(clk), .rst(rst), .load(1'b1), .d(rs2_data_d),        .q(rs2_data));
    register #(.N(32)) pc_plus_4_r       (.clk(clk), .rst(rst), .load(1'b1), .d(pc_plus_4_d),       .q(pc_plus_4));
    register #(.N(32)) pc_plus_imm_r     (.clk(clk), .rst(rst), .load(1'b1), .d(pc_plus_imm_d),     .q(pc_plus_imm));
    register #(.N(5))  rd_r              (.clk(clk), .rst(rst), .load(1'b1), .d(rd_d),              .q(rd));
    register #(.N(3))  funct3_r          (.clk(clk), .rst(rst), .load(1'b1), .d(funct3_d),          .q(funct3));
    register #(.N(1))  c_mem_read_r      (.clk(clk), .rst(rst), .load(1'b1), .d(c_mem_read_d),      .q(c_mem_read));
    register #(.N(1))  c_mem_write_r     (.clk(clk), .rst(rst), .load(1'b1), .d(c_mem_write_d),     .q(c_mem_write));
    register #(.N(2))  wb_src_r          (.clk(clk), .rst(rst), .load(1'b1), .d(wb_src_d),          .q(wb_src));
    register #(.N(1))  c_reg_write_r     (.clk(clk), .rst(rst), .load(1'b1), .d(c_reg_write_d),     .q(c_reg_write));
    register #(.N(1))  halt_r            (.clk(clk), .rst(rst), .load(1'b1), .d(halt_d),            .q(halt));
    register #(.N(1))  c_branch_r        (.clk(clk), .rst(rst), .load(1'b1), .d(c_branch_d),        .q(c_branch));
    register #(.N(1))  c_jump_r          (.clk(clk), .rst(rst), .load(1'b1), .d(c_jump_d),          .q(c_jump));
    register #(.N(1))  c_jalr_r          (.clk(clk), .rst(rst), .load(1'b1), .d(c_jalr_d),          .q(c_jalr));
    register #(.N(1))  flag_z_r          (.clk(clk), .rst(rst), .load(1'b1), .d(flag_z_d),          .q(flag_z));
    register #(.N(1))  flag_c_r          (.clk(clk), .rst(rst), .load(1'b1), .d(flag_c_d),          .q(flag_c));
    register #(.N(1))  flag_v_r          (.clk(clk), .rst(rst), .load(1'b1), .d(flag_v_d),          .q(flag_v));
    register #(.N(1))  flag_n_r          (.clk(clk), .rst(rst), .load(1'b1), .d(flag_n_d),          .q(flag_n));
    register #(.N(1))  predicted_taken_r (.clk(clk), .rst(rst), .load(1'b1), .d(predicted_taken_d), .q(predicted_taken));

endmodule
