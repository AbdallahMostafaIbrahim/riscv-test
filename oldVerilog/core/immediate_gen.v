/*******************************************************************
*
* Module: immediate_gen.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Immediate generator covering all formats.
*              Output is a 32-bit immediate ready to drop into 
*              the ALU or PC adder since B and J immediates
*              already include left shifts, so no extra shift
*              module is needed.
*
**********************************************************************/
`timescale 1ns / 1ps
`include "defines.v"

module immediate_gen (
    input      [31:0] inst,
    output reg [31:0] imm
);

    wire [4:0] opcode;
    assign opcode = inst[`IR_opcode];

    always @(*) begin
        case (opcode)
            `OPCODE_Arith_I,                   // I-ALU
            `OPCODE_Load,                      // Loads
            `OPCODE_JALR: begin                // JALR
                imm = { {20{inst[31]}}, inst[31:20] };
            end
            `OPCODE_Store: begin               // Stores (S-type)
                imm = { {20{inst[31]}}, inst[31:25], inst[11:7] };
            end
            `OPCODE_Branch: begin              // Branches (B-type)
                imm = { {19{inst[31]}},
                        inst[31], inst[7],
                        inst[30:25], inst[11:8],
                        1'b0 };
            end
            `OPCODE_LUI,                       // LUI
            `OPCODE_AUIPC: begin               // AUIPC
                imm = { inst[31:12], 12'b0 };
            end
            `OPCODE_JAL: begin                 // JAL (J-type)
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
