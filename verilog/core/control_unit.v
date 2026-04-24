/*******************************************************************
*
* Module: control_unit.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Decodes the 32-bit instruction and outputs the 
*              control signals for the datapath. Covers all 37 implemented
*              RV32I instructions plus the halting opcodes (ECALL, EBREAK,
*              FENCE, FENCE.TSO, PAUSE).
*
*              Control signals:
*              alu_sel:   4-bit ALU operation selector (details in alu.v and defines.v)
*              alu_src_a: 2'b00 = rs1, 2'b01 = pc, 2'b10 = 32'b0
*              alu_src_b: 1'b0  = rs2, 1'b1  = imm
*              branch:    1 for conditional branches (drives branch_unit)
*              jump:      1 for JAL / JALR
*              jalr:      1 for JALR only
*              mem_read:  1 for loads    
*              mem_write: 1 for stores   (enables write_mask in data_mem)
*              wb_src:    2'b00 = alu, 2'b01 = mem, 2'b10 = pc+4
*              reg_write: 1 when rd should be written on the next clk edge
*              halt:      1 for ECALL / EBREAK / FENCE / FENCE.TSO / PAUSE (freezes PC and stops reg / mem writes)
*
**********************************************************************/
`timescale 1ns / 1ps
`include "defines.v"

module control_unit (
    input      [31:0] inst,
    output reg [3:0]  alu_sel,
    output reg [1:0]  alu_src_a,
    output reg        alu_src_b,
    output reg        branch,
    output reg        jump,
    output reg        jalr,
    output reg        mem_read,
    output reg        mem_write,
    output reg [1:0]  wb_src,
    output reg        reg_write,
    output reg        halt
);

    wire [4:0] opcode;
    wire [2:0] funct3;
    wire       inst30;

    assign opcode = inst[`IR_opcode];
    assign funct3 = inst[`IR_funct3];
    assign inst30 = inst[30];

    always @(*) begin
        // Safe defaults - act like a no-op that writes nowhere.
        alu_sel   = `ALU_ADD;
        alu_src_a = 2'b00;
        alu_src_b = 1'b0;
        branch    = 1'b0;
        jump      = 1'b0;
        jalr      = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        wb_src    = 2'b00;
        reg_write = 1'b0;
        halt      = 1'b0;

        // Treat inst = 32'b0 as a pipeline bubble (NOP). Opcode 5'b00_000
        // would otherwise decode as LOAD, which silently propagates
        // mem_read=1 through ID/EX into EX/MEM and causes a spurious
        // mem_stall one cycle later. The pipeline register bubbles
        // (flush, reset) inject 0x0 as their "no instruction" sentinel,
        // so we must treat that encoding as a NOP here. The only real
        // RV32I encoding lost is `lb x0, 0(x0)`, which already discards
        // its result -- no practical program emits it.
        if (inst == 32'b0) begin
            // keep all-zero safe defaults (NOP)
        end
        else case (opcode)
            // ---------------- R-type -----------------------------
            `OPCODE_Arith_R: begin
                case ({inst30, funct3})
                    {1'b0, `F3_ADD}:  alu_sel = `ALU_ADD;
                    {1'b1, `F3_ADD}:  alu_sel = `ALU_SUB;
                    {1'b0, `F3_SLL}:  alu_sel = `ALU_SLL;
                    {1'b0, `F3_SLT}:  alu_sel = `ALU_SLT;
                    {1'b0, `F3_SLTU}: alu_sel = `ALU_SLTU;
                    {1'b0, `F3_XOR}:  alu_sel = `ALU_XOR;
                    {1'b0, `F3_SRL}:  alu_sel = `ALU_SRL;
                    {1'b1, `F3_SRL}:  alu_sel = `ALU_SRA;
                    {1'b0, `F3_OR}:   alu_sel = `ALU_OR;
                    {1'b0, `F3_AND}:  alu_sel = `ALU_AND;
                    default:          alu_sel = `ALU_ADD;
                endcase
                alu_src_a = 2'b00;
                alu_src_b = 1'b0;
                wb_src    = 2'b00;
                reg_write = 1'b1;
            end

            // ---------------- I-ALU ------------------------------
            // SLLI / SRLI / SRAI take inst30 to pick SRL vs SRA.
            `OPCODE_Arith_I: begin
                case (funct3)
                    `F3_ADD:  alu_sel = `ALU_ADD;
                    `F3_SLT:  alu_sel = `ALU_SLT;
                    `F3_SLTU: alu_sel = `ALU_SLTU;
                    `F3_XOR:  alu_sel = `ALU_XOR;
                    `F3_OR:   alu_sel = `ALU_OR;
                    `F3_AND:  alu_sel = `ALU_AND;
                    `F3_SLL:  alu_sel = `ALU_SLL;
                    `F3_SRL:  alu_sel = inst30 ? `ALU_SRA : `ALU_SRL;
                    default:  alu_sel = `ALU_ADD;
                endcase
                alu_src_a = 2'b00;
                alu_src_b = 1'b1;
                wb_src    = 2'b00;
                reg_write = 1'b1;
            end

            // ---------------- Loads ------------------------------
            `OPCODE_Load: begin
                alu_sel   = `ALU_ADD;        // rs1 + imm
                alu_src_a = 2'b00;
                alu_src_b = 1'b1;
                mem_read  = 1'b1;
                wb_src    = 2'b01;
                reg_write = 1'b1;
            end

            // ---------------- Stores -----------------------------
            `OPCODE_Store: begin
                alu_sel   = `ALU_ADD;        // rs1 + imm
                alu_src_a = 2'b00;
                alu_src_b = 1'b1;
                mem_write = 1'b1;
                reg_write = 1'b0;
            end

            // ---------------- Branches ---------------------------
            `OPCODE_Branch: begin
                alu_sel   = `ALU_SUB;        // rs1 - rs2, flags to branch_unit
                alu_src_a = 2'b00;
                alu_src_b = 1'b0;
                branch    = 1'b1;
                reg_write = 1'b0;
            end

            // ---------------- LUI --------------------------------
            // rd = 0 + imm (U-type already has low 12 bits zero).
            `OPCODE_LUI: begin
                alu_sel   = `ALU_ADD;
                alu_src_a = 2'b10;           // zero
                alu_src_b = 1'b1;            // imm
                wb_src    = 2'b00;
                reg_write = 1'b1;
            end

            // ---------------- AUIPC ------------------------------
            // rd = pc + imm
            `OPCODE_AUIPC: begin
                alu_sel   = `ALU_ADD;
                alu_src_a = 2'b01;           // pc
                alu_src_b = 1'b1;            // imm
                wb_src    = 2'b00;
                reg_write = 1'b1;
            end

            // ---------------- JAL --------------------------------
            // pc_next = pc + imm_J ; rd = pc + 4
            `OPCODE_JAL: begin
                alu_sel   = `ALU_ADD;
                alu_src_a = 2'b00;
                alu_src_b = 1'b0;
                jump      = 1'b1;
                jalr      = 1'b0;
                wb_src    = 2'b10;
                reg_write = 1'b1;
            end

            // ---------------- JALR -------------------------------
            // pc_next = (rs1 + imm) & ~1 ; rd = pc + 4
            `OPCODE_JALR: begin
                alu_sel   = `ALU_ADD;
                alu_src_a = 2'b00;
                alu_src_b = 1'b1;
                jump      = 1'b1;
                jalr      = 1'b1;
                wb_src    = 2'b10;
                reg_write = 1'b1;
            end

            // ---------------- Halting opcodes --------------------
            // SYSTEM (ECALL, EBREAK) and MISC-MEM (FENCE, FENCE.TSO,
            // PAUSE) both freeze the PC via the halt flag.
            `OPCODE_SYSTEM,
            5'b00_011: begin                 // MISC-MEM (FENCE family)
                halt = 1'b1;
            end

            default: begin
                alu_sel   = `ALU_ADD;
                alu_src_a = 2'b00;
                alu_src_b = 1'b0;
                branch    = 1'b0;
                jump      = 1'b0;
                jalr      = 1'b0;
                mem_read  = 1'b0;
                mem_write = 1'b0;
                wb_src    = 2'b00;
                reg_write = 1'b0;
                halt      = 1'b0;
            end
        endcase
    end

endmodule
