/*******************************************************************
*
* Module: branch_unit.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Conditional-branch evaluator. Reads the ALU status
*              flags produced by rs1 - rs2 (the control unit forces
*              alu_sel = SUB for all branches) and decides whether
*              the branch is taken based on funct3.
*
*              funct3 mapping (RV32I):
*                  000 - BEQ    taken when  z
*                  001 - BNE    taken when ~z
*                  100 - BLT    taken when  n ^ v       (signed <)
*                  101 - BGE    taken when ~(n ^ v)     (signed >=)
*                  110 - BLTU   taken when ~c           (unsigned <)
*                  111 - BGEU   taken when  c           (unsigned >=)
*
*              The `branch` input gates the output: if the current
*              instruction is not a branch, taken is forced to 0.
*
* Change history: 2026-04-14 - MS2: initial version.
*
**********************************************************************/
`timescale 1ns / 1ps

module branch_unit (
    input            branch,
    input      [2:0] funct3,
    input            z,
    input            c,
    input            v,
    input            n,
    output reg       taken
);

    always @(*) begin
        taken = 1'b0;
        if (branch) begin
            case (funct3)
                3'b000:  taken =  z;
                3'b001:  taken = ~z;
                3'b100:  taken =  (n ^ v);
                3'b101:  taken = ~(n ^ v);
                3'b110:  taken = ~c;
                3'b111:  taken =  c;
                default: taken =  1'b0;
            endcase
        end
        else begin
            taken = 1'b0;
        end
    end

endmodule
