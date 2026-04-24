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
            `OPCODE_Load: begin
                imm = { {20{inst[31]}}, inst[31:20] };
            end
            `OPCODE_Store: begin
                imm = { {20{inst[31]}}, inst[31:25], inst[11:7] };
            end
            `OPCODE_Branch: begin
                imm = { {19{inst[31]}},
                        inst[31], inst[7],
                        inst[30:25], inst[11:8],
                        1'b0 };
            end
            default: imm = 32'b0;
        endcase
    end

endmodule
