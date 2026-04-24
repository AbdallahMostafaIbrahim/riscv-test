`timescale 1ns / 1ps
`include "defines.v"

// Ctrl bundle layout (MSB..LSB):
//   [7] RegWrite   (WB)
//   [6] MemToReg   (WB)
//   [5] Branch     (MEM)
//   [4] MemRead    (MEM)
//   [3] MemWrite   (MEM)
//   [2:1] ALUOp    (EX)
//   [0] ALUSrc     (EX)
module control_unit (
    input      [31:0] inst,
    output reg [7:0]  ctrl
);

    wire [4:0] opcode;
    assign opcode = inst[`IR_opcode];

    always @(*) begin
        case (opcode)
            `OPCODE_Arith_R: ctrl = 8'b1_0_0_0_0_10_0;
            `OPCODE_Load:    ctrl = 8'b1_1_0_1_0_00_1;
            `OPCODE_Store:   ctrl = 8'b0_0_0_0_1_00_1;
            `OPCODE_Branch:  ctrl = 8'b0_0_1_0_0_01_0;
            default:         ctrl = 8'b0_0_0_0_0_00_0;
        endcase
    end

endmodule
