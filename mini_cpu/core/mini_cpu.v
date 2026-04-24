`timescale 1ns / 1ps
`include "defines.v"

module mini_cpu (
    input clk,
    input rst
);

    wire [31:0] pc_out;
    wire [31:0] pc_next;

    register #(.N(32)) pc_reg (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   (pc_next),
        .q   (pc_out)
    );

    wire [31:0] pc_plus_4;
    wire        pc_plus_4_cout;

    ripple #(.N(32)) pc_add_4 (
        .a   (pc_out),
        .b   (32'd4),
        .cin (1'b0),
        .sum (pc_plus_4),
        .cout(pc_plus_4_cout)
    );

    wire [31:0] pc_plus_imm;
    wire        pc_plus_imm_cout;

    wire [31:0] instruction;

    inst_mem imem (
        .addr    (pc_out),
        .data_out(instruction)
    );

    wire [1:0] alu_sel;
    wire       alu_src_b;
    wire       c_branch;
    wire       c_mem_read;
    wire       c_mem_write;
    wire       c_mem_to_reg;
    wire       c_reg_write;

    control_unit cu (
        .inst      (instruction),
        .alu_sel   (alu_sel),
        .alu_src_b (alu_src_b),
        .branch    (c_branch),
        .mem_read  (c_mem_read),
        .mem_write (c_mem_write),
        .mem_to_reg(c_mem_to_reg),
        .reg_write (c_reg_write)
    );

    wire [31:0] imm;

    immediate_gen imm_gen (
        .inst(instruction),
        .imm (imm)
    );

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] wb_data;

    reg_file rf (
        .clk         (clk),
        .rst         (rst),
        .write_enable(c_reg_write),
        .read_addr_1 (instruction[`IR_rs1]),
        .read_addr_2 (instruction[`IR_rs2]),
        .write_addr  (instruction[`IR_rd]),
        .write_data  (wb_data),
        .read_data_1 (rs1_data),
        .read_data_2 (rs2_data)
    );

    wire [31:0] alu_b;
    assign alu_b = alu_src_b ? imm : rs2_data;

    wire [31:0] alu_out;
    wire        alu_zero;

    alu #(.N(32)) alu_unit (
        .a  (rs1_data),
        .b  (alu_b),
        .sel(alu_sel),
        .out(alu_out),
        .z  (alu_zero)
    );

    ripple #(.N(32)) pc_add_imm (
        .a   (pc_out),
        .b   (imm),
        .cin (1'b0),
        .sum (pc_plus_imm),
        .cout(pc_plus_imm_cout)
    );

    wire [31:0] dmem_rdata;

    data_mem dmem (
        .clk      (clk),
        .mem_read (c_mem_read),
        .mem_write(c_mem_write),
        .addr     (alu_out),
        .wdata    (rs2_data),
        .rdata    (dmem_rdata)
    );

    assign wb_data = c_mem_to_reg ? dmem_rdata : alu_out;

    wire branch_taken;
    assign branch_taken = c_branch & alu_zero;

    assign pc_next = branch_taken ? pc_plus_imm : pc_plus_4;

endmodule
