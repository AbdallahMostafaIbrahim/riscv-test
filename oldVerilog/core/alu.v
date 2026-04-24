/*******************************************************************
*
* Module: alu.v
* Project: RISCV Processor
* Author: Arch Island
* Description: ALU with 4-bit selector
*
**********************************************************************/
`timescale 1ns / 1ps
`include "defines.v"

module alu #(
    parameter N = 32
) (
    input      [N-1:0] a,
    input      [N-1:0] b,
    input      [3:0]   sel,
    output reg [N-1:0] out,
    output             z,
    output             c,
    output             v,
    output             n
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
            `ALU_ADD:  out = add_out;
            `ALU_SUB:  out = add_out;
            `ALU_SLL:  out = a <<  b[4:0];
            `ALU_SLT:  out = { {(N-1){1'b0}}, ($signed(a) < $signed(b)) };
            `ALU_SLTU: out = { {(N-1){1'b0}}, (a < b) };
            `ALU_XOR:  out = a ^ b;
            `ALU_SRL:  out = a >>  b[4:0];
            `ALU_SRA:  out = $signed(a) >>> b[4:0];
            `ALU_OR:   out = a | b;
            `ALU_AND:  out = a & b;
            `ALU_PASS: out = b;
            default:   out = {N{1'b0}};
        endcase
    end

    assign z = (out == {N{1'b0}});
    assign n = out[N-1];
    assign c = add_cout;
    assign v = (a[N-1] == b_eff[N-1]) && (add_out[N-1] != a[N-1]);

endmodule
