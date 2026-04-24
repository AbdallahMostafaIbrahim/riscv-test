/*******************************************************************
*
* Module: mem_wb_reg.v
* Project: RISCV Processor
* Description: MEM/WB pipeline register. Carries the three candidate
*              writeback sources (ALU result, loaded data, pc+4) and
*              the writeback control bits. No bubble logic: by the
*              time an instruction reaches MEM it is committed.
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

    localparam N = 105;

    wire [N-1:0] d;
    wire [N-1:0] q;

    assign d = {
        halt_in,
        c_reg_write_in,
        wb_src_in,
        rd_in,
        pc_plus_4_in,
        load_out_in,
        alu_out_in
    };

    register #(.N(N)) r (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   (d),
        .q   (q)
    );

    assign alu_out     = q[31:0];
    assign load_out    = q[63:32];
    assign pc_plus_4   = q[95:64];
    assign rd          = q[100:96];
    assign wb_src      = q[102:101];
    assign c_reg_write = q[103];
    assign halt        = q[104];

endmodule
