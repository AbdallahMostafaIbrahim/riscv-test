/*******************************************************************
*
* Module: immediate_gen.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Immediate generator covering all five RV32I formats
*              (I / S / B / U / J). Output is a 32-bit value ready
*              to drop into the ALU or PC adder; B and J immediates
*              already include the implicit multiply-by-two, so no
*              downstream left shift is needed.
*
*              Format selection is driven purely from the opcode
*              (inst[6:0]). R-type and any unrecognised opcode
*              (including the halt opcodes where the immediate is
*              meaningless) return zero.
*
* Change history: 2026-04-14 - Cleanup pass.
*                 2026-04-14 - MS2: rewritten for all 5 formats,
*                              no external left shifter.
*
**********************************************************************/
`timescale 1ns / 1ps

module immediate_gen (
    input      [31:0] inst,
    output reg [31:0] imm
);

    wire [6:0] opcode;
    assign opcode = inst[6:0];

    always @(*) begin
        case (opcode)
            7'b0010011,                        // I-ALU
            7'b0000011,                        // Loads
            7'b1100111: begin                  // JALR
                imm = { {20{inst[31]}}, inst[31:20] };
            end
            7'b0100011: begin                  // Stores (S-type)
                imm = { {20{inst[31]}}, inst[31:25], inst[11:7] };
            end
            7'b1100011: begin                  // Branches (B-type)
                imm = { {19{inst[31]}},
                        inst[31], inst[7],
                        inst[30:25], inst[11:8],
                        1'b0 };
            end
            7'b0110111,                        // LUI
            7'b0010111: begin                  // AUIPC
                imm = { inst[31:12], 12'b0 };
            end
            7'b1101111: begin                  // JAL (J-type)
                imm = { {11{inst[31]}},
                        inst[31], inst[19:12],
                        inst[20], inst[30:21],
                        1'b0 };
            end
            default: begin
                imm = 32'b0;
            end
        endcase
    end

endmodule
