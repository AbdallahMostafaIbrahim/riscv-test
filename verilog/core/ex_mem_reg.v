/*******************************************************************
*
* Module: ex_mem_reg.v
* Project: RISCV Processor
* Description: EX/MEM pipeline register. Carries the ALU result,
*              rs2 data (for stores), PC arithmetic, ALU flags, and
*              the control bits MEM needs to resolve a branch.
*              bubble zeros the input on flush so wrong-path
*              register writes or dmem writes never happen.
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

    localparam N = 182;

    wire [N-1:0] d_fresh;
    wire [N-1:0] d;
    wire [N-1:0] q;

    assign d_fresh = {
        predicted_taken_in,
        pc_in,
        flag_n_in,
        flag_v_in,
        flag_c_in,
        flag_z_in,
        c_jalr_in,
        c_jump_in,
        c_branch_in,
        halt_in,
        c_reg_write_in,
        wb_src_in,
        c_mem_write_in,
        c_mem_read_in,
        funct3_in,
        rd_in,
        pc_plus_imm_in,
        pc_plus_4_in,
        rs2_data_in,
        alu_out_in
    };

    assign d = bubble ? {N{1'b0}} : d_fresh;

    register #(.N(N)) r (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   (d),
        .q   (q)
    );

    assign alu_out         = q[31:0];
    assign rs2_data        = q[63:32];
    assign pc_plus_4       = q[95:64];
    assign pc_plus_imm     = q[127:96];
    assign rd              = q[132:128];
    assign funct3          = q[135:133];
    assign c_mem_read      = q[136];
    assign c_mem_write     = q[137];
    assign wb_src          = q[139:138];
    assign c_reg_write     = q[140];
    assign halt            = q[141];
    assign c_branch        = q[142];
    assign c_jump          = q[143];
    assign c_jalr          = q[144];
    assign flag_z          = q[145];
    assign flag_c          = q[146];
    assign flag_v          = q[147];
    assign flag_n          = q[148];
    assign pc              = q[180:149];
    assign predicted_taken = q[181];

endmodule
