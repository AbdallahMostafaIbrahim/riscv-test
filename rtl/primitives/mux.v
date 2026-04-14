/*******************************************************************
*
* Module: mux.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Parameterized N-bit 2-to-1 multiplexer.
*              out = (sel == 0) ? a : b
*
* Change history: 2026-04-14 - Cleanup pass: header, formatting,
*                              lowercase port names.
*
**********************************************************************/
`timescale 1ns / 1ps

module mux #(
    parameter N = 32
) (
    input  [N-1:0] a,
    input  [N-1:0] b,
    input          sel,
    output [N-1:0] out
);

    assign out = sel ? b : a;

endmodule
