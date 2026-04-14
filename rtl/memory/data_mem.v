/*******************************************************************
*
* Module: data_mem.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Byte-addressable data memory. 4 KiB organised as
*              1024 words of 32 bits, with per-byte write enables
*              (wstrb). Reads are combinational and always return
*              the full 32-bit word at addr[11:2]; byte / halfword
*              extraction happens in the load_unit. Writes are
*              synchronous on the positive clock edge, one byte
*              lane per asserted bit of wstrb.
*
*              Initial contents are loaded from mem/data.hex via
*              $readmemh (the standard FPGA BRAM-init idiom).
*
* Change history: 2026-04-14 - Cleanup pass.
*                 2026-04-14 - MS2: byte-write-enables, widened to
*                              4 KiB, combinational read, no longer
*                              gates read on mem_read.
*
**********************************************************************/
`timescale 1ns / 1ps

module data_mem (
    input         clk,
    input  [31:0] addr,
    input  [31:0] wdata,
    input  [3:0]  wstrb,
    output [31:0] rdata
);

    reg [31:0] mem [0:1023];

    initial begin
        $readmemh("mem/data.hex", mem);
    end

    wire [9:0] word_addr;
    assign word_addr = addr[11:2];

    always @(posedge clk) begin
        if (wstrb[0]) mem[word_addr][ 7: 0] <= wdata[ 7: 0];
        if (wstrb[1]) mem[word_addr][15: 8] <= wdata[15: 8];
        if (wstrb[2]) mem[word_addr][23:16] <= wdata[23:16];
        if (wstrb[3]) mem[word_addr][31:24] <= wdata[31:24];
    end

    assign rdata = mem[word_addr];

endmodule
