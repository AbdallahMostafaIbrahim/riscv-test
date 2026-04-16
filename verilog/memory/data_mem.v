/*******************************************************************
*
* Module: data_mem.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Byte-addressable data memory. 4 KiB of 1024 words.
*              a word is 32 bits. We write with per-byte write enables
*              (write_mask). Reads are combinational and always return
*              the full 32-bit word at addr[11:2] (loading halfword
*              and bytes is handled in load_unit). Writes are
*              synchronous on the positive clock edge based on the 
*              write_mask.
*
*              To store half word, write_mask should be 4'b0011 or 4'b1100.
*              To store a byte, write_mask should have only one bit set.
*              To store a word, write_mask should be 4'b1111.
*
*              Initial contents are loaded from data.hex using
*              $readmemh.
*
**********************************************************************/
`timescale 1ns / 1ps

module data_mem (
    input         clk,
    input  [31:0] addr,
    input  [31:0] wdata,
    input  [3:0]  write_mask,
    output [31:0] rdata
);

    reg [31:0] mem [0:1023];

    initial begin
        $readmemh("data.hex", mem);
    end

    wire [9:0] word_addr;
    assign word_addr = addr[11:2];

    always @(posedge clk) begin
        if (write_mask[0]) mem[word_addr][7:0] <= wdata[7:0];
        if (write_mask[1]) mem[word_addr][15:8] <= wdata[15:8];
        if (write_mask[2]) mem[word_addr][23:16] <= wdata[23:16];
        if (write_mask[3]) mem[word_addr][31:24] <= wdata[31:24];
    end

    assign rdata = mem[word_addr];

endmodule
