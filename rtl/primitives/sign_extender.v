/*******************************************************************
*
* Module: sign_extender.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Parameterized sign extender from N bits to M bits.
*
* Change history: 2026-04-14 - Cleanup pass: header, formatting.
*
**********************************************************************/
`timescale 1ns / 1ps

module sign_extender #(
    parameter N = 12,
    parameter M = 32
) (
    input  [N-1:0] in,
    output [M-1:0] out
);

    assign out = { {(M-N){in[N-1]}}, in };

endmodule
