/*******************************************************************
*
* Module: riscv.v
* Project: riscv32Project
* Author: Arch Island
* Description: Top-level 5-stage pipelined RV32I core.
*              Stages: IF -> ID -> EX -> MEM -> WB.
*              Pipeline registers: IF/ID, ID/EX, EX/MEM, MEM/WB,
*              each built from the `register` primitive.
*
*              Branches and jumps are resolved in the MEM stage
*              (textbook MIPS-style). The ALU in EX produces the
*              flags and the pc+imm adder computes the target;
*              both are latched in EX/MEM and the branch_unit /
*              PC redirect live in MEM.
*
*              Hazard handling is intentionally omitted at this
*              step: no forwarding, no stalls, no branch flushing.
*              Data hazards (read-after-write) and control hazards
*              (branches/jumps resolved in MEM => 3 delay slots)
*              will mis-execute on dependent sequences.
*
*              Halt: once a halting opcode (ECALL/EBREAK/FENCE/
*              FENCE.TSO/PAUSE) enters ID or later, the PC and
*              IF/ID register freeze so only safe halt instructions
*              keep flowing through the pipe.
*
*              Memories are separate (instruction, data) and byte
*              addressable.
*
* Change history: 2026-04-23 - Pipelined the datapath; added the
*                              four pipeline registers using the
*                              register primitive.
*                 2026-04-23 - Moved branch resolution from EX to
*                              MEM to match textbook pipeline.
*
**********************************************************************/
`timescale 1ns / 1ps
`include "defines.v"

module riscv (
    input clk,
    input rst
);

    /* ================================================================
     * Signals that flow "backwards" in the datapath:
     *   WB -> ID : reg-file write port
     *   EX -> IF : branch/jump redirect
     *   halt flags in ID / ID-EX / EX-MEM / MEM-WB -> IF
     * Declared up front so every stage can reference them.
     * ================================================================ */
    wire [31:0] wb_data_wb;
    wire [4:0]  rd_addr_wb;
    wire        reg_write_wb;

    wire [31:0] pc_next;
    wire        halted;
    wire        halt_pending;
    wire        pc_load;
    wire        stall;
    wire        flush;

    // halt_pending: halt is anywhere in the pipe -> freeze fetch.
    // halted     : halt has reached WB -> program done (testbench
    //              signal); used by external tooling after all
    //              real instructions ahead of the halt have
    //              committed.
    assign pc_load = ~halt_pending & (flush | ~stall);

    /* ================================================================
     * IF Stage
     * ================================================================ */
    wire [31:0] pc_if;
    wire [31:0] pc_plus_4_if;
    wire [31:0] inst_if;
    wire        pc_plus_4_if_cout;

    register #(.N(32)) pc_reg (
        .clk (clk),
        .rst (rst),
        .load(pc_load),
        .d   (pc_next),
        .q   (pc_if)
    );

    // Alias exposed for testbenches that probe the committed PC.
    wire [31:0] pc_out;
    assign pc_out = pc_if;

    ripple #(.N(32)) pc_add_4 (
        .a   (pc_if),
        .b   (32'd4),
        .cin (1'b0),
        .sum (pc_plus_4_if),
        .cout(pc_plus_4_if_cout)
    );

    // inst_if and dmem_rdata_mem both come from the unified memory
    // instance, wired at the bottom of the module. See the "Unified
    // Memory (single port)" section.

    /* ================================================================
     * IF/ID Pipeline Register
     *
     * Packed layout (LSB first):
     *   [31:0]   pc
     *   [63:32]  pc_plus_4
     *   [95:64]  inst
     *
     * load = ~halted : freezes when a halt is somewhere in the pipe
     * so only the halt instruction keeps being seen by ID.
     * ================================================================ */
    wire [95:0] if_id_d_fresh;
    wire [95:0] if_id_d;
    wire [95:0] if_id_q;
    wire        if_id_load;

    wire [31:0] if_id_pc;
    wire [31:0] if_id_pc_plus_4;
    wire [31:0] if_id_inst;

    // Load = 0 freezes (load-use stall). Flush overrides the stall
    // so a branch redirect can always clear the wrong-path inst.
    assign if_id_load    = ~halt_pending & (flush | ~stall);
    assign if_id_d_fresh = { inst_if, pc_plus_4_if, pc_if };
    assign if_id_d       = flush ? 96'b0 : if_id_d_fresh;

    register #(.N(96)) if_id_reg (
        .clk (clk),
        .rst (rst),
        .load(if_id_load),
        .d   (if_id_d),
        .q   (if_id_q)
    );

    assign if_id_pc        = if_id_q[31:0];
    assign if_id_pc_plus_4 = if_id_q[63:32];
    assign if_id_inst      = if_id_q[95:64];

    /* ================================================================
     * ID Stage
     * ================================================================ */
    wire [3:0] alu_sel_id;
    wire [1:0] alu_src_a_id;
    wire       alu_src_b_id;
    wire       c_branch_id;
    wire       c_jump_id;
    wire       c_jalr_id;
    wire       c_mem_read_id;
    wire       c_mem_write_id;
    wire [1:0] wb_src_id;
    wire       c_reg_write_id;
    wire       halt_id;

    control_unit cu (
        .inst     (if_id_inst),
        .alu_sel  (alu_sel_id),
        .alu_src_a(alu_src_a_id),
        .alu_src_b(alu_src_b_id),
        .branch   (c_branch_id),
        .jump     (c_jump_id),
        .jalr     (c_jalr_id),
        .mem_read (c_mem_read_id),
        .mem_write(c_mem_write_id),
        .wb_src   (wb_src_id),
        .reg_write(c_reg_write_id),
        .halt     (halt_id)
    );

    wire [31:0] imm_id;

    immediate_gen imm_gen (
        .inst(if_id_inst),
        .imm (imm_id)
    );

    wire [31:0] rs1_data_id;
    wire [31:0] rs2_data_id;
    wire [4:0]  rd_id;
    wire [4:0]  rs1_id;
    wire [4:0]  rs2_id;
    wire [2:0]  funct3_id;

    assign rd_id     = if_id_inst[`IR_rd];
    assign rs1_id    = if_id_inst[`IR_rs1];
    assign rs2_id    = if_id_inst[`IR_rs2];
    assign funct3_id = if_id_inst[`IR_funct3];

    reg_file rf (
        .clk         (clk),
        .rst         (rst),
        .write_enable(reg_write_wb),
        .read_addr_1 (if_id_inst[`IR_rs1]),
        .read_addr_2 (if_id_inst[`IR_rs2]),
        .write_addr  (rd_addr_wb),
        .write_data  (wb_data_wb),
        .read_data_1 (rs1_data_id),
        .read_data_2 (rs2_data_id)
    );

    // Load-use hazard detection. The stall signal freezes PC and
    // IF/ID, and bubbles ID/EX for one cycle so the dependent
    // instruction finds the load's value in MEM/WB next cycle.
    hazard_unit hu (
        .id_ex_rd       (id_ex_rd),
        .id_ex_mem_read (id_ex_c_mem_read),
        .if_id_rs1      (rs1_id),
        .if_id_rs2      (rs2_id),
        .ex_mem_mem_read (ex_mem_c_mem_read),
        .ex_mem_mem_write(ex_mem_c_mem_write),
        .stall          (stall)
    );

    /* ================================================================
     * ID/EX Pipeline Register
     *
     * Packed layout (LSB first):
     *   [31:0]    pc
     *   [63:32]   pc_plus_4
     *   [95:64]   rs1_data
     *   [127:96]  rs2_data
     *   [159:128] imm
     *   [164:160] rd
     *   [167:165] funct3
     *   [171:168] alu_sel
     *   [173:172] alu_src_a
     *   [174]     alu_src_b
     *   [175]     c_branch
     *   [176]     c_jump
     *   [177]     c_jalr
     *   [178]     c_mem_read
     *   [179]     c_mem_write
     *   [181:180] wb_src
     *   [182]     c_reg_write
     *   [183]     halt
     *   [188:184] rs1
     *   [193:189] rs2
     * ================================================================ */
    wire [193:0] id_ex_d_fresh;
    wire [193:0] id_ex_d;
    wire [193:0] id_ex_q;

    assign id_ex_d_fresh = {
        rs2_id,
        rs1_id,
        halt_id,
        c_reg_write_id,
        wb_src_id,
        c_mem_write_id,
        c_mem_read_id,
        c_jalr_id,
        c_jump_id,
        c_branch_id,
        alu_src_b_id,
        alu_src_a_id,
        alu_sel_id,
        funct3_id,
        rd_id,
        imm_id,
        rs2_data_id,
        rs1_data_id,
        if_id_pc_plus_4,
        if_id_pc
    };

    // Bubble ID/EX when either:
    //   - stall : load-use stall keeps the dependent inst in ID.
    //   - flush : branch resolved in MEM -> wrong-path inst in ID
    //             must not be allowed into EX.
    assign id_ex_d = (stall | flush) ? 194'b0 : id_ex_d_fresh;

    register #(.N(194)) id_ex_reg (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   (id_ex_d),
        .q   (id_ex_q)
    );

    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_pc_plus_4;
    wire [31:0] id_ex_rs1_data;
    wire [31:0] id_ex_rs2_data;
    wire [31:0] id_ex_imm;
    wire [4:0]  id_ex_rd;
    wire [2:0]  id_ex_funct3;
    wire [3:0]  id_ex_alu_sel;
    wire [1:0]  id_ex_alu_src_a;
    wire        id_ex_alu_src_b;
    wire        id_ex_c_branch;
    wire        id_ex_c_jump;
    wire        id_ex_c_jalr;
    wire        id_ex_c_mem_read;
    wire        id_ex_c_mem_write;
    wire [1:0]  id_ex_wb_src;
    wire        id_ex_c_reg_write;
    wire        id_ex_halt;
    wire [4:0]  id_ex_rs1;
    wire [4:0]  id_ex_rs2;

    assign id_ex_pc          = id_ex_q[31:0];
    assign id_ex_pc_plus_4   = id_ex_q[63:32];
    assign id_ex_rs1_data    = id_ex_q[95:64];
    assign id_ex_rs2_data    = id_ex_q[127:96];
    assign id_ex_imm         = id_ex_q[159:128];
    assign id_ex_rd          = id_ex_q[164:160];
    assign id_ex_funct3      = id_ex_q[167:165];
    assign id_ex_alu_sel     = id_ex_q[171:168];
    assign id_ex_alu_src_a   = id_ex_q[173:172];
    assign id_ex_alu_src_b   = id_ex_q[174];
    assign id_ex_c_branch    = id_ex_q[175];
    assign id_ex_c_jump      = id_ex_q[176];
    assign id_ex_c_jalr      = id_ex_q[177];
    assign id_ex_c_mem_read  = id_ex_q[178];
    assign id_ex_c_mem_write = id_ex_q[179];
    assign id_ex_wb_src      = id_ex_q[181:180];
    assign id_ex_c_reg_write = id_ex_q[182];
    assign id_ex_halt        = id_ex_q[183];
    assign id_ex_rs1         = id_ex_q[188:184];
    assign id_ex_rs2         = id_ex_q[193:189];

    /* ================================================================
     * EX Stage
     *
     * The forwarding unit picks the freshest value for rs1/rs2 from
     * one of three places: the id_ex register (no hazard), EX/MEM
     * (instruction one ahead wrote it), or MEM/WB (two ahead). The
     * result feeds the existing alu_src_a / alu_src_b muxes.
     * ================================================================ */
    wire [1:0] forward_a;
    wire [1:0] forward_b;

    forwarding_unit fwd (
        .id_ex_rs1       (id_ex_rs1),
        .id_ex_rs2       (id_ex_rs2),
        .ex_mem_rd       (ex_mem_rd),
        .ex_mem_reg_write(ex_mem_c_reg_write),
        .mem_wb_rd       (mem_wb_rd),
        .mem_wb_reg_write(mem_wb_c_reg_write),
        .forward_a       (forward_a),
        .forward_b       (forward_b)
    );

    reg [31:0] rs1_fwd_ex;
    reg [31:0] rs2_fwd_ex;

    always @(*) begin
        case (forward_a)
            2'b00:   rs1_fwd_ex = id_ex_rs1_data;
            2'b10:   rs1_fwd_ex = ex_mem_alu_out;
            2'b01:   rs1_fwd_ex = wb_data_wb;
            default: rs1_fwd_ex = id_ex_rs1_data;
        endcase
    end

    always @(*) begin
        case (forward_b)
            2'b00:   rs2_fwd_ex = id_ex_rs2_data;
            2'b10:   rs2_fwd_ex = ex_mem_alu_out;
            2'b01:   rs2_fwd_ex = wb_data_wb;
            default: rs2_fwd_ex = id_ex_rs2_data;
        endcase
    end

    reg  [31:0] alu_a_ex;
    wire [31:0] alu_b_ex;

    always @(*) begin
        case (id_ex_alu_src_a)
            2'b00:   alu_a_ex = rs1_fwd_ex;
            2'b01:   alu_a_ex = id_ex_pc;
            2'b10:   alu_a_ex = 32'b0;
            default: alu_a_ex = rs1_fwd_ex;
        endcase
    end

    assign alu_b_ex = id_ex_alu_src_b ? id_ex_imm : rs2_fwd_ex;

    wire [31:0] alu_out_ex;
    wire        flag_z_ex;
    wire        flag_c_ex;
    wire        flag_v_ex;
    wire        flag_n_ex;

    alu #(.N(32)) alu_unit (
        .a  (alu_a_ex),
        .b  (alu_b_ex),
        .sel(id_ex_alu_sel),
        .out(alu_out_ex),
        .z  (flag_z_ex),
        .c  (flag_c_ex),
        .v  (flag_v_ex),
        .n  (flag_n_ex)
    );

    // pc + imm: branch / JAL target, latched into EX/MEM and used
    // by the MEM stage to decide the next PC.
    wire [31:0] pc_plus_imm_ex;
    wire        pc_plus_imm_ex_cout;

    ripple #(.N(32)) pc_add_imm (
        .a   (id_ex_pc),
        .b   (id_ex_imm),
        .cin (1'b0),
        .sum (pc_plus_imm_ex),
        .cout(pc_plus_imm_ex_cout)
    );

    /* ================================================================
     * EX/MEM Pipeline Register
     *
     * Carries the ALU result + the extra signals MEM needs to
     * resolve the branch: ALU flags, pc+imm, and the branch/jump
     * control bits.
     *
     * Packed layout (LSB first):
     *   [31:0]    alu_out
     *   [63:32]   rs2_data
     *   [95:64]   pc_plus_4
     *   [127:96]  pc_plus_imm
     *   [132:128] rd
     *   [135:133] funct3
     *   [136]     c_mem_read
     *   [137]     c_mem_write
     *   [139:138] wb_src
     *   [140]     c_reg_write
     *   [141]     halt
     *   [142]     c_branch
     *   [143]     c_jump
     *   [144]     c_jalr
     *   [145]     flag_z
     *   [146]     flag_c
     *   [147]     flag_v
     *   [148]     flag_n
     * ================================================================ */
    wire [148:0] ex_mem_d_fresh;
    wire [148:0] ex_mem_d;
    wire [148:0] ex_mem_q;

    assign ex_mem_d_fresh = {
        flag_n_ex,
        flag_v_ex,
        flag_c_ex,
        flag_z_ex,
        id_ex_c_jalr,
        id_ex_c_jump,
        id_ex_c_branch,
        id_ex_halt,
        id_ex_c_reg_write,
        id_ex_wb_src,
        id_ex_c_mem_write,
        id_ex_c_mem_read,
        id_ex_funct3,
        id_ex_rd,
        pc_plus_imm_ex,
        id_ex_pc_plus_4,
        rs2_fwd_ex,
        alu_out_ex
    };

    // Bubble EX/MEM on flush: the inst in EX was fetched from the
    // wrong path and must not reach MEM (it would cause dmem writes
    // or reg writebacks that the taken branch was supposed to skip).
    assign ex_mem_d = flush ? 149'b0 : ex_mem_d_fresh;

    register #(.N(149)) ex_mem_reg (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   (ex_mem_d),
        .q   (ex_mem_q)
    );

    wire [31:0] ex_mem_alu_out;
    wire [31:0] ex_mem_rs2_data;
    wire [31:0] ex_mem_pc_plus_4;
    wire [31:0] ex_mem_pc_plus_imm;
    wire [4:0]  ex_mem_rd;
    wire [2:0]  ex_mem_funct3;
    wire        ex_mem_c_mem_read;
    wire        ex_mem_c_mem_write;
    wire [1:0]  ex_mem_wb_src;
    wire        ex_mem_c_reg_write;
    wire        ex_mem_halt;
    wire        ex_mem_c_branch;
    wire        ex_mem_c_jump;
    wire        ex_mem_c_jalr;
    wire        ex_mem_flag_z;
    wire        ex_mem_flag_c;
    wire        ex_mem_flag_v;
    wire        ex_mem_flag_n;

    assign ex_mem_alu_out     = ex_mem_q[31:0];
    assign ex_mem_rs2_data    = ex_mem_q[63:32];
    assign ex_mem_pc_plus_4   = ex_mem_q[95:64];
    assign ex_mem_pc_plus_imm = ex_mem_q[127:96];
    assign ex_mem_rd          = ex_mem_q[132:128];
    assign ex_mem_funct3      = ex_mem_q[135:133];
    assign ex_mem_c_mem_read  = ex_mem_q[136];
    assign ex_mem_c_mem_write = ex_mem_q[137];
    assign ex_mem_wb_src      = ex_mem_q[139:138];
    assign ex_mem_c_reg_write = ex_mem_q[140];
    assign ex_mem_halt        = ex_mem_q[141];
    assign ex_mem_c_branch    = ex_mem_q[142];
    assign ex_mem_c_jump      = ex_mem_q[143];
    assign ex_mem_c_jalr      = ex_mem_q[144];
    assign ex_mem_flag_z      = ex_mem_q[145];
    assign ex_mem_flag_c      = ex_mem_q[146];
    assign ex_mem_flag_v      = ex_mem_q[147];
    assign ex_mem_flag_n      = ex_mem_q[148];

    /* ================================================================
     * MEM Stage
     * ================================================================ */
    wire [31:0] store_wdata_mem;
    wire [3:0]  store_write_mask_mem;
    wire [31:0] dmem_rdata_mem;
    wire [31:0] load_out_mem;

    store_unit su (
        .rs2_data  (ex_mem_rs2_data),
        .addr_low  (ex_mem_alu_out[1:0]),
        .funct3    (ex_mem_funct3),
        .mem_write (ex_mem_c_mem_write),
        .wdata     (store_wdata_mem),
        .write_mask(store_write_mask_mem)
    );

    load_unit lu (
        .word_in  (dmem_rdata_mem),
        .addr_low (ex_mem_alu_out[1:0]),
        .funct3   (ex_mem_funct3),
        .load_out (load_out_mem)
    );

    /* ================================================================
     * Unified Memory (single port)
     *
     * One memory, one port, shared between IF (instruction fetch)
     * and MEM (load / store). Arbitration is implicit: whenever MEM
     * needs the port (ex_mem has a load or store), hazard_unit
     * asserts mem_stall, which freezes PC and IF/ID. IF therefore
     * only tries to fetch on cycles the port is free.
     *
     * The address mux picks MEM's address when MEM is active, else
     * IF's PC. The read output feeds both inst_if (for IF) and
     * dmem_rdata_mem (for the load_unit). Since the two consumers
     * are never active the same cycle (mem_stall guarantees it),
     * routing the same rdata to both is safe.
     * ================================================================ */
    wire        mem_port_is_data;
    wire [31:0] mem_addr;
    wire [31:0] mem_rdata;

    assign mem_port_is_data = ex_mem_c_mem_read | ex_mem_c_mem_write;
    assign mem_addr         = mem_port_is_data ? ex_mem_alu_out
                                               : pc_if;

    memory mem_unit (
        .clk       (clk),
        .addr      (mem_addr),
        .wdata     (store_wdata_mem),
        .write_mask(store_write_mask_mem),
        .rdata     (mem_rdata)
    );

    assign inst_if        = mem_rdata;
    assign dmem_rdata_mem = mem_rdata;

    // Branch resolution (moved here from EX). The ALU flags and
    // pc+imm were computed in EX and are now arriving through the
    // EX/MEM register.
    wire branch_taken_mem;

    branch_unit bu (
        .branch(ex_mem_c_branch),
        .funct3(ex_mem_funct3),
        .z     (ex_mem_flag_z),
        .c     (ex_mem_flag_c),
        .v     (ex_mem_flag_v),
        .n     (ex_mem_flag_n),
        .taken (branch_taken_mem)
    );

    // jalr target: force 2-byte alignment (rs1 + imm) & ~1
    wire [31:0] jalr_target_mem;
    wire        pc_rel_taken_mem;
    assign jalr_target_mem  = { ex_mem_alu_out[31:1], 1'b0 };
    assign pc_rel_taken_mem = branch_taken_mem
                              | (ex_mem_c_jump & ~ex_mem_c_jalr);

    /* ================================================================
     * MEM/WB Pipeline Register
     *
     * Packed layout (LSB first):
     *   [31:0]    alu_out
     *   [63:32]   load_out
     *   [95:64]   pc_plus_4
     *   [100:96]  rd
     *   [102:101] wb_src
     *   [103]     c_reg_write
     *   [104]     halt
     * ================================================================ */
    wire [104:0] mem_wb_d;
    wire [104:0] mem_wb_q;

    assign mem_wb_d = {
        ex_mem_halt,
        ex_mem_c_reg_write,
        ex_mem_wb_src,
        ex_mem_rd,
        ex_mem_pc_plus_4,
        load_out_mem,
        ex_mem_alu_out
    };

    register #(.N(105)) mem_wb_reg (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   (mem_wb_d),
        .q   (mem_wb_q)
    );

    wire [31:0] mem_wb_alu_out;
    wire [31:0] mem_wb_load_out;
    wire [31:0] mem_wb_pc_plus_4;
    wire [4:0]  mem_wb_rd;
    wire [1:0]  mem_wb_wb_src;
    wire        mem_wb_c_reg_write;
    wire        mem_wb_halt;

    assign mem_wb_alu_out     = mem_wb_q[31:0];
    assign mem_wb_load_out    = mem_wb_q[63:32];
    assign mem_wb_pc_plus_4   = mem_wb_q[95:64];
    assign mem_wb_rd          = mem_wb_q[100:96];
    assign mem_wb_wb_src      = mem_wb_q[102:101];
    assign mem_wb_c_reg_write = mem_wb_q[103];
    assign mem_wb_halt        = mem_wb_q[104];

    /* ================================================================
     * WB Stage
     * ================================================================ */
    reg [31:0] wb_data_r;

    always @(*) begin
        case (mem_wb_wb_src)
            2'b00:   wb_data_r = mem_wb_alu_out;
            2'b01:   wb_data_r = mem_wb_load_out;
            2'b10:   wb_data_r = mem_wb_pc_plus_4;
            default: wb_data_r = mem_wb_alu_out;
        endcase
    end

    assign wb_data_wb   = wb_data_r;
    assign rd_addr_wb   = mem_wb_rd;
    assign reg_write_wb = mem_wb_c_reg_write;

    /* ================================================================
     * Halt propagation
     *
     * halt_pending: any halt in the pipe. Freezes PC + IF/ID so no
     *   garbage is fetched past the halt while earlier instructions
     *   drain through MEM and WB.
     *
     * halted: the halt has *reached* WB. External / testbench signal
     *   -- every instruction that was ahead of it in program order
     *   has already committed by this point.
     * ================================================================ */
    assign halt_pending = halt_id
                        | id_ex_halt
                        | ex_mem_halt
                        | mem_wb_halt;

    assign halted = mem_wb_halt;

    /* ================================================================
     * Branch / Jump flush
     * Any PC redirect from MEM (taken branch, JAL, or JALR) means
     * the three wrong-path instructions currently in IF, ID, and
     * EX must be squashed. The flush signal bubbles IF/ID, ID/EX,
     * and EX/MEM so they can't cause writebacks or dmem writes.
     * ================================================================ */
    assign flush = pc_rel_taken_mem | ex_mem_c_jalr;

    /* ================================================================
     * Next PC Logic
     * Branches and jumps are resolved in MEM. When not redirected
     * we fall through to IF's pc+4. With flush wired, wrong-path
     * instructions behind the branch are turned into bubbles.
     * ================================================================ */
    reg [31:0] pc_next_r;
    assign pc_next = pc_next_r;

    always @(*) begin
        if (ex_mem_c_jalr)
            pc_next_r = jalr_target_mem;
        else if (pc_rel_taken_mem)
            pc_next_r = ex_mem_pc_plus_imm;
        else
            pc_next_r = pc_plus_4_if;
    end

endmodule
