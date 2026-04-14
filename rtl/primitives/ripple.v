/*******************************************************************
*
* Module: ripple.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Parameterized N-bit ripple-carry adder with carry-in
*              and carry-out. Replaces the previous rca module.
*
* Change history: 2026-04-14 - Cleanup pass: header, dot-notation
*                              instantiation, formatting.
*
**********************************************************************/
`timescale 1ns / 1ps

module ripple #(
    parameter N = 8
) (
    input  [N-1:0] a,
    input  [N-1:0] b,
    input          cin,
    output [N-1:0] sum,
    output         cout
);

    wire [N:0] carry;
    assign carry[0] = cin;

    genvar j;
    generate
        for (j = 0; j < N; j = j + 1) begin : gen_fa
            full_adder fa (
                .a   (a[j]),
                .b   (b[j]),
                .cin (carry[j]),
                .sum (sum[j]),
                .cout(carry[j+1])
            );
        end
    endgenerate

    assign cout = carry[N];

endmodule
