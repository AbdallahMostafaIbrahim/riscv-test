/*******************************************************************
*
* Module: full_adder.v
* Project: RISCV Processor
* Author: Arch Island
* Description: 1-bit full adder used as the building block of the
*              ripple-carry adder.
*
* Change history: 2026-04-14 - Cleanup pass: header, formatting.
*
**********************************************************************/
`timescale 1ns / 1ps

module full_adder (
    input  a,
    input  b,
    input  cin,
    output sum,
    output cout
);

    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (b & cin) | (a & cin);

endmodule
