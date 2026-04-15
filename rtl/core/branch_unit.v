/*******************************************************************
*
* Module: branch_unit.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Conditional-branch evaluator. Uses the alu_out from
*              the ALU (rs1 - rs2) and the branch funct3 to 
*              determine if a branch is taken.
*
**********************************************************************/
`timescale 1ns / 1ps
`include "defines.v"

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
                `BR_BEQ:  taken =  z;
                `BR_BNE:  taken = ~z;
                `BR_BLT:  taken =  (n ^ v);
                `BR_BGE:  taken = ~(n ^ v);
                `BR_BLTU: taken = ~c;
                `BR_BGEU: taken =  c;
                default:  taken =  1'b0;
            endcase
        end
        else begin
            taken = 1'b0;
        end
    end

endmodule
