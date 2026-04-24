/*******************************************************************
*
* Module: pc_control_unit.v
* Project: riscv32Project
* Description: Resolves next PC and pipeline flush. Combines MEM-stage
*              branch/jump resolution with the IF-stage predictor
*              output. A correctly-predicted taken branch does NOT
*              flush -- the pipe already flows to the target.
*
*              Next-PC priority:
*                1. JALR              -> (rs1 + imm) & ~1
*                2. pc+imm redirect   (NT->T mispredict OR JAL)
*                3. pc+4 redirect     (T->NT mispredict)
*                4. predictor taken   -> BTB target
*                5. fall through      -> pc+4
*
**********************************************************************/
`timescale 1ns / 1ps

module pc_control_unit (
    // MEM-stage resolution
    input         ex_mem_c_branch,
    input         ex_mem_c_jump,
    input         ex_mem_c_jalr,
    input         ex_mem_predicted_taken,
    input         branch_taken,
    input  [31:0] ex_mem_alu_out,
    input  [31:0] ex_mem_pc_plus_4,
    input  [31:0] ex_mem_pc_plus_imm,

    // IF-stage prediction
    input         predict_taken,
    input  [31:0] predict_target,
    input  [31:0] pc_plus_4,

    output        flush,
    output [31:0] pc_next
);

    // jalr target: force 2-byte alignment (rs1 + imm) & ~1
    wire [31:0] jalr_target;
    assign jalr_target = { ex_mem_alu_out[31:1], 1'b0 };

    wire mispred_nt_to_t;
    wire mispred_t_to_nt;
    assign mispred_nt_to_t = ex_mem_c_branch &  branch_taken & ~ex_mem_predicted_taken;
    assign mispred_t_to_nt = ex_mem_c_branch & ~branch_taken &  ex_mem_predicted_taken;

    wire pc_rel_taken;
    wire pc_rel_not_taken;
    assign pc_rel_taken     = mispred_nt_to_t | (ex_mem_c_jump & ~ex_mem_c_jalr);
    assign pc_rel_not_taken = mispred_t_to_nt;

    // Flush on any misprediction or JALR. Squashes the three wrong-path
    // instructions in IF/ID/EX.
    assign flush = pc_rel_taken | pc_rel_not_taken | ex_mem_c_jalr;

    reg [31:0] pc_next_r;
    assign pc_next = pc_next_r;

    always @(*) begin
        if (ex_mem_c_jalr)
            pc_next_r = jalr_target;
        else if (pc_rel_taken)
            pc_next_r = ex_mem_pc_plus_imm;
        else if (pc_rel_not_taken)
            pc_next_r = ex_mem_pc_plus_4;
        else if (predict_taken)
            pc_next_r = predict_target;
        else
            pc_next_r = pc_plus_4;
    end

endmodule
