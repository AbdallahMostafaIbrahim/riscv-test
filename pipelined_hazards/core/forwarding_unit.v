`timescale 1ns / 1ps

// EX-stage forwarding.  EX/MEM has priority over MEM/WB since it's
// the newer value.  forward{A,B} select among:
//   00 - ID/EX.RegR{1,2} (no forward)
//   01 - wb_data         (forward from MEM/WB)
//   10 - EX/MEM.ALU_out  (forward from EX/MEM)
module forwarding_unit (
    input  [4:0] id_ex_rs1,
    input  [4:0] id_ex_rs2,
    input  [4:0] ex_mem_rd,
    input  [4:0] mem_wb_rd,
    input        ex_mem_reg_write,
    input        mem_wb_reg_write,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

    always @(*) begin
        // forward_a
        if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // forward_b
        if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end

endmodule
