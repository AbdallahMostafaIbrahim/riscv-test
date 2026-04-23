/*******************************************************************
*
* Module: memory.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Unified, single-port, byte-addressable memory. Holds
*              both instructions and data in the same array. 4 KiB,
*              organised as 1024 32-bit words. Reads are
*              combinational; writes are synchronous on the positive
*              clock edge, gated per byte by a 4-bit write_mask.
*
*              The port is shared between IF (fetch) and MEM (load /
*              store). Only one consumer uses the port each cycle.
*              The hazard_unit asserts mem_stall whenever the MEM
*              stage needs the port, freezing IF until MEM is done,
*              so the two consumers never collide at this module's
*              interface.
*
*              Initial contents load from inst.hex. Test programs
*              should keep their data above some safe offset (e.g.
*              0x400) so stores don't overwrite code.
*
* Change history: 2026-04-23 - Initial version. Replaces separate
*                              inst_mem.v and data_mem.v for MS3's
*                              single-port requirement.
*
**********************************************************************/
`timescale 1ns / 1ps

module memory (
    input         clk,
    input  [31:0] addr,
    input  [31:0] wdata,
    input  [3:0]  write_mask,
    output [31:0] rdata
);

    reg     [31:0] mem [0:1023];
    integer        i;

    // Zero the data region first so partial-word stores (sh, sb)
    // leave predictable bytes in untouched lanes. Then overlay the
    // program image from inst.hex.
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 32'b0;
        $readmemh("inst.hex", mem);
    end

    wire [9:0] word_addr;
    assign word_addr = addr[11:2];

    always @(posedge clk) begin
        if (write_mask[0]) mem[word_addr][7:0]   <= wdata[7:0];
        if (write_mask[1]) mem[word_addr][15:8]  <= wdata[15:8];
        if (write_mask[2]) mem[word_addr][23:16] <= wdata[23:16];
        if (write_mask[3]) mem[word_addr][31:24] <= wdata[31:24];
    end

    assign rdata = mem[word_addr];

endmodule
