/*******************************************************************
*
* Module: riscv.v
* Project: riscv32Project
* Author: Arch Island
* Description: Top-level single-cycle RV32I core. Supports all 37
*              real user-level instructions and treats the five
*              instructions: ECALL, EBREAK, PAUSE, FENCE, FENCE.TSO)
*              as program end (halt).
*
*              Memories are separate (instruction, data) and byte
*              addressable.
*
**********************************************************************/
`timescale 1ns / 1ps
`include "defines.v"

module riscv (
    input clk,
    input rst
);

    // Program counter
    wire [31:0] pc_out;
    wire [31:0] pc_next;
    wire        pc_load;

    wire        halted;

    // Don't load a new PC if we're halted
    assign pc_load = ~halted;

    register #(.N(32)) pc_reg (
        .clk (clk),
        .rst (rst),
        .load(pc_load),
        .d   (pc_next),
        .q   (pc_out)
    );

    // PC + 4
    wire [31:0] pc_plus_4;
    wire        pc_plus_4_cout;

    ripple #(.N(32)) pc_add_4 (
        .a   (pc_out),
        .b   (32'd4),
        .cin (1'b0),
        .sum (pc_plus_4),
        .cout(pc_plus_4_cout)
    );

    // Instruction fetch Stage
    wire [31:0] instruction;

    inst_mem imem (
        .addr    (pc_out),
        .data_out(instruction)
    );

    // Decode Stage
    wire [3:0] alu_sel;
    wire [1:0] alu_src_a;
    wire       alu_src_b;
    wire       c_branch;
    wire       c_jump;
    wire       c_jalr;
    wire       c_mem_read;
    wire       c_mem_write;
    wire [1:0] wb_src;
    wire       c_reg_write;

    control_unit cu (
        .inst     (instruction),
        .alu_sel  (alu_sel),
        .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b),
        .branch   (c_branch),
        .jump     (c_jump),
        .jalr     (c_jalr),
        .mem_read (c_mem_read),
        .mem_write(c_mem_write),
        .wb_src   (wb_src),
        .reg_write(c_reg_write),
        .halt     (halted)
    );

    // Immediate generator
    wire [31:0] imm;

    immediate_gen imm_gen (
        .inst(instruction),
        .imm (imm)
    );

    // Register file
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] wb_data;
    wire        reg_write_eff;

    // Don't write to the register file if we're halted
    assign reg_write_eff = c_reg_write & ~halted;

    reg_file rf (
        .clk         (clk),
        .rst         (rst),
        .write_enable(reg_write_eff),
        .read_addr_1 (instruction[`IR_rs1]),
        .read_addr_2 (instruction[`IR_rs2]),
        .write_addr  (instruction[`IR_rd]),
        .write_data  (wb_data),
        .read_data_1 (rs1_data),
        .read_data_2 (rs2_data)
    );

    // ALU input muxes
    reg  [31:0] alu_a;
    wire [31:0] alu_b;

    always @(*) begin
        case (alu_src_a)
            2'b00:   alu_a = rs1_data;
            2'b01:   alu_a = pc_out;
            2'b10:   alu_a = 32'b0;
            default: alu_a = rs1_data;
        endcase
    end

    assign alu_b = alu_src_b ? imm : rs2_data;

    // ALU
    wire [31:0] alu_out;
    wire        flag_z;
    wire        flag_c;
    wire        flag_v;
    wire        flag_n;

    alu #(.N(32)) alu_unit (
        .a  (alu_a),
        .b  (alu_b),
        .sel(alu_sel),
        .out(alu_out),
        .z  (flag_z),
        .c  (flag_c),
        .v  (flag_v),
        .n  (flag_n)
    );

    // Branch Unit
    wire branch_taken;

    branch_unit bu (
        .branch(c_branch),
        .funct3(instruction[`IR_funct3]),
        .z     (flag_z),
        .c     (flag_c),
        .v     (flag_v),
        .n     (flag_n),
        .taken (branch_taken)
    );

    // PC + imm (branch and JAL target)
    wire [31:0] pc_plus_imm;
    wire        pc_plus_imm_cout;

    ripple #(.N(32)) pc_add_imm (
        .a   (pc_out),
        .b   (imm),
        .cin (1'b0),
        .sum (pc_plus_imm),
        .cout(pc_plus_imm_cout)
    );

    // Data memory section
    wire        mem_write_eff;
    wire [31:0] store_wdata;
    wire [3:0]  store_write_mask;
    wire [31:0] dmem_rdata;
    wire [31:0] load_out;

    assign mem_write_eff = c_mem_write & ~halted;

    // Store unit: formats rs2_data and generates write mask based on
    // funct3 and the low two bits of the address (alu_out[1:0]).
    store_unit su (
        .rs2_data  (rs2_data),
        .addr_low   (alu_out[1:0]),
        .funct3    (instruction[`IR_funct3]),
        .mem_write (mem_write_eff),
        .wdata     (store_wdata),
        .write_mask(store_write_mask)
    );

    // Byte addressable data memory takes in an address and the data to be
    // written is store_wdata along with byte write mask to support sb/sh/sw.
    data_mem dmem (
        .clk       (clk),
        .addr      (alu_out),
        .wdata     (store_wdata),
        .write_mask(store_write_mask),
        .rdata     (dmem_rdata)
    );

    // Formats the loaded data based on funct3 and the
    // low two bits of the address (alu_out[1:0]) to support lb/lh/lw/lbu/lhu.
    load_unit lu (
        .word_in (dmem_rdata),
        .addr_low (alu_out[1:0]),
        .funct3  (instruction[`IR_funct3]),
        .load_out(load_out)
    );

    // Write-back mux selects between ALU result, load result,
    // and PC+4 (for JAL & JALR) to write back to the register file.
    // based on wb_src control signal.
    reg [31:0] wb_data_r;
    assign wb_data = wb_data_r;

    always @(*) begin
        case (wb_src)
            2'b00:   wb_data_r = alu_out;
            2'b01:   wb_data_r = load_out;
            2'b10:   wb_data_r = pc_plus_4;
            default: wb_data_r = alu_out;
        endcase
    end

    // Next PC Logic:
    // We select the next PC based on whether we have a taken  
    // branch or jump, and if it's a jalr then we use the 
    // jalr_target instead of pc+imm 
    wire [31:0] jalr_target;
    wire        pc_rel_taken;
    reg  [31:0] pc_next_r;
    assign pc_next     = pc_next_r;
    // This forces 2-byte alignment because alu_out could
    // be an odd number because jalr does rs1 + sign_extended(imm) 
    // so we & ~1
    assign jalr_target = { alu_out[31:1], 1'b0 }; 
    // We take the branch target if it's a taken branch
    // or if it's a jump (but not jalr, which uses the jalr_target instead)
    assign pc_rel_taken = branch_taken | (c_jump & ~c_jalr);

    always @(*) begin
        if (c_jalr)
            pc_next_r = jalr_target;
        else if (pc_rel_taken)
            pc_next_r = pc_plus_imm;
        else
            pc_next_r = pc_plus_4;
    end

endmodule
