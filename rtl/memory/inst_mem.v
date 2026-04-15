/*******************************************************************
*
* Module: inst_mem.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Byte-addressable instruction memory. 4 KiB of 1024 words.
*              a word is 32 bits.
*
*              Initial contents are loaded from inst.hex using
*              $readmemh.
**********************************************************************/
`timescale 1ns / 1ps

module inst_mem (
    input  [31:0] addr,
    output [31:0] data_out
);

    reg [31:0] mem [0:1023];

    initial begin
        $readmemh("inst.hex", mem);
    end

    assign data_out = mem[addr[11:2]];

endmodule
