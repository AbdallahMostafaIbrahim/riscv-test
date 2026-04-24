/*******************************************************************
*
* Module: forwarding_unit.v
* Project: riscv32Project
* Description: EX-stage forwarding. Picks the freshest rs1/rs2 from
*              EX/MEM, MEM/WB, or the id_ex register. EX/MEM wins
*              over MEM/WB. Load-use is the hazard unit's job.
*
*              forward_a / forward_b encoding:
*                2'b00 - no forward (id_ex rs1/rs2)
*                2'b10 - forward from EX/MEM alu_out
*                2'b01 - forward from MEM/WB wb_data
*
**********************************************************************/
`timescale 1ns / 1ps

module forwarding_unit (
    input      [4:0] id_ex_rs1,
    input      [4:0] id_ex_rs2,
    input      [4:0] ex_mem_rd,
    input            ex_mem_c_reg_write,
    input      [4:0] mem_wb_rd,
    input            mem_wb_c_reg_write,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

    wire ex_hazard_a;
    wire ex_hazard_b;
    wire mem_hazard_a;
    wire mem_hazard_b;

    assign ex_hazard_a = ex_mem_c_reg_write & (ex_mem_rd != 5'b0) & (ex_mem_rd == id_ex_rs1);
    assign ex_hazard_b = ex_mem_c_reg_write & (ex_mem_rd != 5'b0) & (ex_mem_rd == id_ex_rs2);

    assign mem_hazard_a = mem_wb_c_reg_write & (mem_wb_rd != 5'b0) & (mem_wb_rd == id_ex_rs1);
    assign mem_hazard_b = mem_wb_c_reg_write & (mem_wb_rd != 5'b0) & (mem_wb_rd == id_ex_rs2);

    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        if (ex_hazard_a)       forward_a = 2'b10;
        else if (mem_hazard_a) forward_a = 2'b01;

        if (ex_hazard_b)       forward_b = 2'b10;
        else if (mem_hazard_b) forward_b = 2'b01;
    end

endmodule
