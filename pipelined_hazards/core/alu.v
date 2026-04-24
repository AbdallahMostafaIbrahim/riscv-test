`timescale 1ns / 1ps
`include "defines.v"

module alu #(
    parameter N = 32
) (
    input      [N-1:0] a,
    input      [N-1:0] b,
    input      [1:0]   sel,
    output reg [N-1:0] out,
    output             z
);

    wire         sub_op;
    wire [N-1:0] b_eff;
    wire [N-1:0] add_out;
    wire         add_cout;

    assign sub_op = (sel == `ALU_SUB);
    assign b_eff  = sub_op ? ~b : b;

    ripple #(.N(N)) adder (
        .a   (a),
        .b   (b_eff),
        .cin (sub_op),
        .sum (add_out),
        .cout(add_cout)
    );

    always @(*) begin
        case (sel)
            `ALU_ADD: out = add_out;
            `ALU_SUB: out = add_out;
            `ALU_AND: out = a & b;
            `ALU_OR:  out = a | b;
            default:  out = {N{1'b0}};
        endcase
    end

    assign z = (out == {N{1'b0}});

endmodule
