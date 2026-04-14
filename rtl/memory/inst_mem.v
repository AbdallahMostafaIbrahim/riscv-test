/*******************************************************************
*
* Module: inst_mem.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Byte-addressable instruction memory. 4 KiB arranged
*              as 1024 words of 32 bits. Read-only; contents are
*              loaded from mem/inst.hex at elaboration time via
*              $readmemh. Misaligned fetches silently return the
*              word at addr[11:2].
*
* Change history: 2026-04-14 - Cleanup pass.
*                 2026-04-14 - MS2: widened to 4 KiB and switched
*                              to 32-bit byte address on the port.
*
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
