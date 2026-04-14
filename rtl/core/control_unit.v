/*******************************************************************
*
* Module: control_unit.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Flat single-cycle decoder. Takes the full 32-bit
*              instruction and emits every datapath control signal
*              directly. The decoder covers all 37 implemented
*              RV32I instructions plus the 5 halting opcodes
*              (ECALL, EBREAK, PAUSE, FENCE, FENCE.TSO).
*
*              alu_sel uses the 5-bit encoding {funct7[5], funct3}
*              so R-type is a direct pass-through and I-type shift
*              instructions plug in by replacing funct7[5] with
*              inst[30].
*
*              alu_src_a: 2'b00 = rs1, 2'b01 = pc, 2'b10 = 32'b0
*              alu_src_b: 1'b0  = rs2, 1'b1  = imm
*              wb_src:    2'b00 = alu, 2'b01 = mem, 2'b10 = pc+4
*
* Change history: 2026-04-14 - Cleanup pass.
*                 2026-04-14 - MS2: rewritten as a flat decoder
*                              covering all 37 supported opcodes.
*
**********************************************************************/
`timescale 1ns / 1ps

module control_unit (
    input      [31:0] inst,
    output reg [4:0]  alu_sel,
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

    wire [6:0] opcode;
    wire [2:0] funct3;
    wire       funct7_5;
    wire       inst30;

    assign opcode   = inst[6:0];
    assign funct3   = inst[14:12];
    assign funct7_5 = inst[30];
    assign inst30   = inst[30];

    always @(*) begin
        // Safe defaults - treat the instruction as a no-op that does
        // not write anywhere. Keeps every output driven on every path
        // and prevents inferred latches for unrecognised opcodes.
        alu_sel   = 5'b00000;
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

        case (opcode)
            // ---------------- R-type -----------------------------
            7'b0110011: begin
                alu_sel   = { funct7_5, 1'b0, funct3 };
                alu_src_a = 2'b00;
                alu_src_b = 1'b0;
                wb_src    = 2'b00;
                reg_write = 1'b1;
            end

            // ---------------- I-ALU ------------------------------
            // ADDI / SLTI / SLTIU / XORI / ORI / ANDI use
            //   alu_sel = {1'b0, funct3}
            // SLLI / SRLI / SRAI use
            //   alu_sel = {inst[30], funct3}
            7'b0010011: begin
                if (funct3 == 3'b001 || funct3 == 3'b101)
                    alu_sel = { inst30, 1'b0, funct3 };
                else
                    alu_sel = { 2'b00, funct3 };
                alu_src_a = 2'b00;
                alu_src_b = 1'b1;
                wb_src    = 2'b00;
                reg_write = 1'b1;
            end

            // ---------------- Loads ------------------------------
            7'b0000011: begin
                alu_sel   = 5'b00000;   // ADD (rs1 + imm)
                alu_src_a = 2'b00;
                alu_src_b = 1'b1;
                mem_read  = 1'b1;
                wb_src    = 2'b01;
                reg_write = 1'b1;
            end

            // ---------------- Stores -----------------------------
            7'b0100011: begin
                alu_sel   = 5'b00000;   // ADD (rs1 + imm)
                alu_src_a = 2'b00;
                alu_src_b = 1'b1;
                mem_write = 1'b1;
                reg_write = 1'b0;
            end

            // ---------------- Branches ---------------------------
            7'b1100011: begin
                alu_sel   = 5'b10000;   // SUB (rs1 - rs2) for flags
                alu_src_a = 2'b00;
                alu_src_b = 1'b0;
                branch    = 1'b1;
                reg_write = 1'b0;
            end

            // ---------------- LUI --------------------------------
            // rd = imm (U-type already has the low 12 bits zero).
            // Compute as 0 + imm so the ALU result drives wb.
            7'b0110111: begin
                alu_sel   = 5'b00000;   // ADD
                alu_src_a = 2'b10;      // zero
                alu_src_b = 1'b1;       // imm
                wb_src    = 2'b00;
                reg_write = 1'b1;
            end

            // ---------------- AUIPC ------------------------------
            // rd = pc + imm
            7'b0010111: begin
                alu_sel   = 5'b00000;   // ADD
                alu_src_a = 2'b01;      // pc
                alu_src_b = 1'b1;       // imm
                wb_src    = 2'b00;
                reg_write = 1'b1;
            end

            // ---------------- JAL --------------------------------
            // pc_next = pc + imm_J;  rd = pc + 4
            7'b1101111: begin
                alu_sel   = 5'b00000;
                alu_src_a = 2'b00;
                alu_src_b = 1'b0;
                jump      = 1'b1;
                jalr      = 1'b0;
                wb_src    = 2'b10;      // pc + 4
                reg_write = 1'b1;
            end

            // ---------------- JALR -------------------------------
            // pc_next = (rs1 + imm) & ~1;  rd = pc + 4
            7'b1100111: begin
                alu_sel   = 5'b00000;   // ADD (rs1 + imm)
                alu_src_a = 2'b00;
                alu_src_b = 1'b1;
                jump      = 1'b1;
                jalr      = 1'b1;
                wb_src    = 2'b10;      // pc + 4
                reg_write = 1'b1;
            end

            // ---------------- Halting opcodes --------------------
            // ECALL, EBREAK (SYSTEM) and FENCE, FENCE.TSO, PAUSE
            // (MISC-MEM) freeze the PC via the sticky halt flag.
            7'b1110011,
            7'b0001111: begin
                halt = 1'b1;
            end

            // ---------------- Anything else ----------------------
            default: begin
                alu_sel   = 5'b00000;
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
