`timescale 1ns / 1ps
`include "defines.v"

module control_unit (
    input      [31:0] inst,
    output reg [1:0]  alu_sel,
    output reg        alu_src_b,
    output reg        branch,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,
    output reg        reg_write
);

    wire [4:0] opcode;
    wire [2:0] funct3;
    wire       inst30;

    assign opcode = inst[`IR_opcode];
    assign funct3 = inst[`IR_funct3];
    assign inst30 = inst[30];

    always @(*) begin
        alu_sel    = `ALU_ADD;
        alu_src_b  = 1'b0;
        branch     = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        reg_write  = 1'b0;

        case (opcode)
            `OPCODE_Arith_R: begin
                case (funct3)
                    `F3_ADD_SUB: alu_sel = inst30 ? `ALU_SUB : `ALU_ADD;
                    `F3_AND:     alu_sel = `ALU_AND;
                    `F3_OR:      alu_sel = `ALU_OR;
                    default:     alu_sel = `ALU_ADD;
                endcase
                alu_src_b = 1'b0;
                reg_write = 1'b1;
            end

            `OPCODE_Load: begin
                alu_sel    = `ALU_ADD;
                alu_src_b  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                reg_write  = 1'b1;
            end

            `OPCODE_Store: begin
                alu_sel   = `ALU_ADD;
                alu_src_b = 1'b1;
                mem_write = 1'b1;
            end

            `OPCODE_Branch: begin
                alu_sel   = `ALU_SUB;
                alu_src_b = 1'b0;
                branch    = 1'b1;
            end

            default: begin
            end
        endcase
    end

endmodule
