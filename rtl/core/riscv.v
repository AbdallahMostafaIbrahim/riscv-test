/*******************************************************************
*
* Module: riscv.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Top-level single-cycle RV32I core. Supports all 37
*              real user-level instructions (R-type, I-ALU, loads,
*              stores, branches, LUI, AUIPC, JAL, JALR) and treats
*              the five halting opcodes (ECALL, EBREAK, PAUSE,
*              FENCE, FENCE.TSO) as program-end by freezing the PC
*              via a sticky halted flag.
*
*              Memories are separate (instruction / data) and byte
*              addressable. Split will be unified into a single
*              single-ported memory for MS3.
*
* Change history: 2026-04-14 - Cleanup pass (4 insns).
*                 2026-04-14 - MS2: full RV32I single-cycle core.
*
**********************************************************************/
`timescale 1ns / 1ps

module riscv (
    input clk,
    input rst
);

    // =================================================================
    // Program counter
    // =================================================================
    wire [31:0] pc_out;
    wire [31:0] pc_next;
    wire        pc_load;

    // Halt-related wires defined later; forward declare semantics:
    //   pc_load is high whenever we are not halted and the current
    //   instruction is not itself a halt opcode.
    wire        halted;
    wire        halt_dec;

    assign pc_load = ~(halted | halt_dec);

    register #(.N(32)) pc_reg (
        .clk (clk),
        .rst (rst),
        .load(pc_load),
        .d   (pc_next),
        .q   (pc_out)
    );

    // =================================================================
    // PC + 4
    // =================================================================
    wire [31:0] pc_plus_4;
    wire        pc_plus_4_cout;

    ripple #(.N(32)) pc_add_4 (
        .a   (pc_out),
        .b   (32'd4),
        .cin (1'b0),
        .sum (pc_plus_4),
        .cout(pc_plus_4_cout)
    );

    // =================================================================
    // Instruction fetch
    // =================================================================
    wire [31:0] instruction;

    inst_mem imem (
        .addr    (pc_out),
        .data_out(instruction)
    );

    // =================================================================
    // Decode
    // =================================================================
    wire [4:0] alu_sel;
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
        .halt     (halt_dec)
    );

    // =================================================================
    // Immediate generator
    // =================================================================
    wire [31:0] imm;

    immediate_gen imm_gen (
        .inst(instruction),
        .imm (imm)
    );

    // =================================================================
    // Register file
    // =================================================================
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] wb_data;
    wire        reg_write_eff;

    assign reg_write_eff = c_reg_write & ~halted;

    reg_file rf (
        .clk         (clk),
        .rst         (rst),
        .write_enable(reg_write_eff),
        .read_addr_1 (instruction[19:15]),
        .read_addr_2 (instruction[24:20]),
        .write_addr  (instruction[11:7]),
        .write_data  (wb_data),
        .read_data_1 (rs1_data),
        .read_data_2 (rs2_data)
    );

    // =================================================================
    // ALU input muxes
    // =================================================================
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

    // =================================================================
    // ALU
    // =================================================================
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

    // =================================================================
    // Branch evaluation
    // =================================================================
    wire branch_taken;

    branch_unit bu (
        .branch(c_branch),
        .funct3(instruction[14:12]),
        .z     (flag_z),
        .c     (flag_c),
        .v     (flag_v),
        .n     (flag_n),
        .taken (branch_taken)
    );

    // =================================================================
    // PC + imm (branch / JAL target)
    // =================================================================
    wire [31:0] pc_plus_imm;
    wire        pc_plus_imm_cout;

    ripple #(.N(32)) pc_add_imm (
        .a   (pc_out),
        .b   (imm),
        .cin (1'b0),
        .sum (pc_plus_imm),
        .cout(pc_plus_imm_cout)
    );

    // =================================================================
    // Data memory + store / load formatting
    // =================================================================
    wire        mem_write_eff;
    wire [31:0] store_wdata;
    wire [3:0]  store_wstrb;
    wire [31:0] dmem_rdata;
    wire [31:0] load_out;

    assign mem_write_eff = c_mem_write & ~halted;

    store_unit su (
        .rs2_data (rs2_data),
        .addr_lo  (alu_out[1:0]),
        .funct3   (instruction[14:12]),
        .mem_write(mem_write_eff),
        .wdata    (store_wdata),
        .wstrb    (store_wstrb)
    );

    data_mem dmem (
        .clk  (clk),
        .addr (alu_out),
        .wdata(store_wdata),
        .wstrb(store_wstrb),
        .rdata(dmem_rdata)
    );

    load_unit lu (
        .word_in (dmem_rdata),
        .addr_lo (alu_out[1:0]),
        .funct3  (instruction[14:12]),
        .load_out(load_out)
    );

    // =================================================================
    // Write-back mux
    // =================================================================
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

    // =================================================================
    // Next-PC selection
    // =================================================================
    wire [31:0] jalr_target;
    wire        pc_rel_taken;
    reg  [31:0] pc_next_r;
    assign pc_next     = pc_next_r;
    assign jalr_target = { alu_out[31:1], 1'b0 };
    assign pc_rel_taken = (c_branch & branch_taken) | (c_jump & ~c_jalr);

    always @(*) begin
        if (c_jump & c_jalr)
            pc_next_r = jalr_target;
        else if (pc_rel_taken)
            pc_next_r = pc_plus_imm;
        else
            pc_next_r = pc_plus_4;
    end

    // =================================================================
    // Halt flag
    // =================================================================
    halt_unit halt_u (
        .clk    (clk),
        .rst    (rst),
        .halt_in(halt_dec),
        .halted (halted)
    );

endmodule
