/*******************************************************************
*
* Module: register.v
* Project: RISCV Processor
* Description: Parameterized N-bit register with synchronous load
*              enable and async active-high reset. Built from
*              individual flip_flop primitives driven by a 2:1 mux.
*
**********************************************************************/
`timescale 1ns / 1ps

module register #(
    parameter N = 32
) (
    input              clk,
    input              rst,
    input              load,
    input  [N-1:0]     d,
    output [N-1:0]     q
);

    genvar j;
    generate
        for (j = 0; j < N; j = j + 1) begin : gen_bit
            wire d_next;
            mux #(.N(1)) m (
                .a  (q[j]),
                .b  (d[j]),
                .sel(load),
                .out(d_next)
            );
            flip_flop ff (
                .clk(clk),
                .rst(rst),
                .d  (d_next),
                .q  (q[j])
            );
        end
    endgenerate

endmodule
