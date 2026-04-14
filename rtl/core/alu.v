/*******************************************************************
*
* Module: alu.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Parameterized N-bit ALU for the full RV32I ALU set:
*              ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND.
*              Exposes four status flags (Z, C, V, N) so that the
*              branch_unit can evaluate every conditional branch
*              condition from a single SUB.
*
*              alu_sel encoding mirrors {funct7[5], funct3} from
*              the RISC-V spec:
*                  00000 - ADD
*                  10000 - SUB
*                  00001 - SLL
*                  00010 - SLT   (signed)
*                  00011 - SLTU  (unsigned)
*                  00100 - XOR
*                  00101 - SRL
*                  10101 - SRA
*                  00110 - OR
*                  00111 - AND
*
* Change history: 2026-04-14 - Cleanup pass.
*                 2026-04-14 - MS2: expanded to 10 ops, added flag
*                              outputs, 5-bit selector, behavioural
*                              shifts / compares using native ops.
*
**********************************************************************/
`timescale 1ns / 1ps

module alu #(
    parameter N = 32
) (
    input      [N-1:0] a,
    input      [N-1:0] b,
    input      [4:0]   sel,
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

    assign sub_op = (sel == 5'b10000);
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
            5'b00000: out = add_out;
            5'b10000: out = add_out;
            5'b00001: out = a <<  b[4:0];
            5'b00010: out = { {(N-1){1'b0}}, ($signed(a) < $signed(b)) };
            5'b00011: out = { {(N-1){1'b0}}, (a < b) };
            5'b00100: out = a ^ b;
            5'b00101: out = a >>  b[4:0];
            5'b10101: out = $signed(a) >>> b[4:0];
            5'b00110: out = a | b;
            5'b00111: out = a & b;
            default:  out = {N{1'b0}};
        endcase
    end

    assign z = (out == {N{1'b0}});
    assign n = out[N-1];
    assign c = add_cout;
    assign v = (a[N-1] == b_eff[N-1]) && (add_out[N-1] != a[N-1]);

endmodule
