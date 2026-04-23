/*******************************************************************
*
* Module: reg_file.v
* Project: RISCV Processor
* Author: Arch Island
* Description: 32 x 32-bit RISC-V register file. x0 is hard-wired to zero.
*              Writes are synchronous on the NEGATIVE clock edge
*              (mid-cycle), while reads are combinational. This
*              half-cycle split lets the ID stage read a value
*              written back by WB in the same cycle -- covers the
*              3-instruction RAW case that pure EX/MEM and MEM/WB
*              forwarding can't reach.
*
* Change history: 2026-04-23 - Moved write edge from posedge to
*                              negedge to resolve 3-inst RAW.
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

    always @(negedge clk or posedge rst) begin
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
