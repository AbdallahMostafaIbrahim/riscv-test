/*******************************************************************
*
* Module: forwarding_unit.v
* Project: riscv32Project
* Author: Arch Island
* Description: Classic 5-stage pipeline forwarding unit. Compares
*              the source register numbers of the instruction in
*              EX against the destination register numbers of the
*              instructions in EX/MEM and MEM/WB, and decides
*              whether to bypass the reg-file read with a fresher
*              value.
*
*              Mux selects (forward_a / forward_b):
*                2'b00 - no forward (use id_ex rs1/rs2 data)
*                2'b10 - forward from EX/MEM (ex_mem_alu_out)
*                2'b01 - forward from MEM/WB (wb_data_wb)
*
*              Priority: EX/MEM wins over MEM/WB since it's the
*              newer value. A write to x0 never forwards (x0 is
*              hard-wired to zero in the reg file).
*
*              Not handled here: load-use hazards. A load in EX/MEM
*              only has the address on ex_mem_alu_out, not the
*              loaded word; the dependent instruction must stall
*              one cycle. Stalling is a hazard-unit job.
*
* Change history: 2026-04-23 - Initial version.
*
**********************************************************************/
`timescale 1ns / 1ps

module forwarding_unit (
    input      [4:0] id_ex_rs1,
    input      [4:0] id_ex_rs2,
    input      [4:0] ex_mem_rd,
    input            ex_mem_reg_write,
    input      [4:0] mem_wb_rd,
    input            mem_wb_reg_write,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

    wire ex_hazard_a;
    wire ex_hazard_b;
    wire mem_hazard_a;
    wire mem_hazard_b;

    // EX hazard: instruction in EX/MEM writes a register that the
    // instruction currently in EX wants to read.
    assign ex_hazard_a = ex_mem_reg_write
                       & (ex_mem_rd != 5'b0)
                       & (ex_mem_rd == id_ex_rs1);

    assign ex_hazard_b = ex_mem_reg_write
                       & (ex_mem_rd != 5'b0)
                       & (ex_mem_rd == id_ex_rs2);

    // MEM hazard: instruction in MEM/WB writes a register that EX
    // wants to read, and the newer EX/MEM value doesn't already
    // cover it.
    assign mem_hazard_a = mem_wb_reg_write
                        & (mem_wb_rd != 5'b0)
                        & ~ex_hazard_a
                        & (mem_wb_rd == id_ex_rs1);

    assign mem_hazard_b = mem_wb_reg_write
                        & (mem_wb_rd != 5'b0)
                        & ~ex_hazard_b
                        & (mem_wb_rd == id_ex_rs2);

    always @(*) begin
        // Default: no forwarding.
        forward_a = 2'b00;
        forward_b = 2'b00;

        if (ex_hazard_a)
            forward_a = 2'b10;
        else if (mem_hazard_a)
            forward_a = 2'b01;

        if (ex_hazard_b)
            forward_b = 2'b10;
        else if (mem_hazard_b)
            forward_b = 2'b01;
    end

endmodule
