`timescale 1ns / 1ps
`include "defines.v"

module alu_control (
    input      [1:0] alu_op,
    input      [3:0] func,
    output reg [1:0] alu_sel
);

    always @(*) begin
        case (alu_op)
            `ALUOP_MEM: alu_sel = `ALU_ADD;
            `ALUOP_BEQ: alu_sel = `ALU_SUB;
            `ALUOP_R: begin
                case (func[2:0])
                    `F3_ADD_SUB: alu_sel = func[3] ? `ALU_SUB : `ALU_ADD;
                    `F3_OR:      alu_sel = `ALU_OR;
                    `F3_AND:     alu_sel = `ALU_AND;
                    default:     alu_sel = `ALU_ADD;
                endcase
            end
            default: alu_sel = `ALU_ADD;
        endcase
    end

endmodule
