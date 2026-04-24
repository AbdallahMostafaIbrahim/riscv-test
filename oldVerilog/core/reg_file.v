/*******************************************************************
*
* Module: reg_file.v
* Project: RISCV Processor
* Author: Arch Island
* Description: 32 x 32-bit RISC-V register file. x0 is hard-wired to zero.
*              Writes are synchronous on the positive clock edge,
*              while reads are combinational.
*
**********************************************************************/
`timescale 1ns / 1ps

module reg_file (
    input         clk,
    input         rst,
    input         write_enable,
    input  [4:0]  read_addr_1,
    input  [4:0]  read_addr_2,
    input  [4:0]  write_addr,
    input  [31:0] write_data,
    output [31:0] read_data_1,
    output [31:0] read_data_2
);

    reg [31:0] regs [0:31];
    integer    i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end
        else if (write_enable && (write_addr != 5'b0)) begin
            regs[write_addr] <= write_data;
        end
    end

    assign read_data_1 = regs[read_addr_1];
    assign read_data_2 = regs[read_addr_2];

endmodule
