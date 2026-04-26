/*******************************************************************
*
* Module: memory.v
* Project: RISCV Processor
* Description: Unified single-port byte-addressable memory, 4 KiB
*              (1024 x 32-bit). Holds both instructions and data.
*              Reads combinational, writes synchronous, uses per-byte
*              write_mask. Initial program from inst.hex.
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

    // Zero the array first so we have predictable content
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
