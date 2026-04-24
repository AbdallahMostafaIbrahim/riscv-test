/*******************************************************************
*
* Module: id_ex_reg.v
* Project: RISCV Processor
* Description: ID/EX pipeline register. Carries everything EX needs
*              (operands, immediate, ALU controls) and everything
*              that must survive past EX (mem/wb controls, halt).
*              load is hard-wired to 1; bubble zeros the input on
*              stall (load-use) or flush (branch redirect) so no
*              wrong-path work enters EX.
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
    output        halt
);

    localparam N = 194;

    wire [N-1:0] d_fresh;
    wire [N-1:0] d;
    wire [N-1:0] q;

    assign d_fresh = {
        rs2_in,
        rs1_in,
        halt_in,
        c_reg_write_in,
        wb_src_in,
        c_mem_write_in,
        c_mem_read_in,
        c_jalr_in,
        c_jump_in,
        c_branch_in,
        alu_src_b_in,
        alu_src_a_in,
        alu_sel_in,
        funct3_in,
        rd_in,
        imm_in,
        rs2_data_in,
        rs1_data_in,
        pc_plus_4_in,
        pc_in
    };

    assign d = bubble ? {N{1'b0}} : d_fresh;

    register #(.N(N)) r (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   (d),
        .q   (q)
    );

    assign pc          = q[31:0];
    assign pc_plus_4   = q[63:32];
    assign rs1_data    = q[95:64];
    assign rs2_data    = q[127:96];
    assign imm         = q[159:128];
    assign rd          = q[164:160];
    assign funct3      = q[167:165];
    assign alu_sel     = q[171:168];
    assign alu_src_a   = q[173:172];
    assign alu_src_b   = q[174];
    assign c_branch    = q[175];
    assign c_jump      = q[176];
    assign c_jalr      = q[177];
    assign c_mem_read  = q[178];
    assign c_mem_write = q[179];
    assign wb_src      = q[181:180];
    assign c_reg_write = q[182];
    assign halt        = q[183];
    assign rs1         = q[188:184];
    assign rs2         = q[193:189];

endmodule
