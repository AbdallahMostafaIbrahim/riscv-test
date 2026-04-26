/*******************************************************************
*
* Module: flip_flop.v
* Project: RISCV Processor
* Description: Positive-edge-triggered D flip-flop with async
*              active-high reset.
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
