/*******************************************************************
*
* Module: flip_flop.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Positive-edge-triggered D flip-flop with async
*              active-high reset.
*
* Change history: 2026-04-14 - Cleanup pass: header, formatting,
*                              lowercase port names.
*
**********************************************************************/
`timescale 1ns / 1ps

module flip_flop (
    input      clk,
    input      rst,
    input      d,
    output reg q
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            q <= 1'b0;
        else
            q <= d;
    end

endmodule
