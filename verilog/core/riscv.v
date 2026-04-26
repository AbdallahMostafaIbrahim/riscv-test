/*******************************************************************
*
* Module: riscv.v
* Project: RISCV Processor
* Description: 5-stage pipelined RV32I core (IF -> ID -> EX -> MEM -> WB).
*              Forwarding + load-use stall cover data hazards. Branches
*              resolve in MEM against a 1-bit predictor; mispredictions
*              flush three stages. IF and MEM share one memory port.
*
**********************************************************************/
`timescale 1ns / 1ps
`include "defines.v"

module riscv (
    input clk,
    input rst
);

    // Backward-flowing signals: WB writeback, MEM redirects, halt flags.
    wire [31:0] wb_data;
    wire [31:0] pc_next;
    wire        halted;
    wire        halting;
    wire        pc_load;
    wire        stall;
    wire        flush;

    // We prioritize flush over halt in case we have branch instruction
    // then a an ebreak instruction following it, so we block the halt
    // if it was an invalid branch prediction that would've been flushed.
    assign pc_load = flush | (~halting & ~stall);

    // IF Stage
    wire [31:0] pc_out;
    wire [31:0] pc_plus_4;
    wire [31:0] inst;
    wire        pc_plus_4_cout;
    wire        predict_taken;
    wire [31:0] predict_target;

    register #(.N(32)) pc_reg (
        .clk (clk),
        .rst (rst),
        .load(pc_load),
        .d   (pc_next),
        .q   (pc_out)
    );

    branch_predictor bp (
        .clk           (clk),
        .rst           (rst),
        .pc_if         (pc_out),
        .predict_taken (predict_taken),
        .predict_target(predict_target),
        .update_valid  (ex_mem_c_branch),
        .update_pc     (ex_mem_pc),
        .update_taken  (branch_taken),
        .update_target (ex_mem_pc_plus_imm)
    );

    ripple #(.N(32)) pc_add_4 (
        .a   (pc_out),
        .b   (32'd4),
        .cin (1'b0),
        .sum (pc_plus_4),
        .cout(pc_plus_4_cout)
    );

    // IF/ID Pipeline Register
    // load=0 freezes (load-use stall); flush overrides to clear wrong-path inst.
    wire        if_id_load;
    wire [31:0] if_id_pc;
    wire [31:0] if_id_pc_plus_4;
    wire [31:0] if_id_inst;
    wire        if_id_predicted_taken;

    assign if_id_load = flush | (~halting & ~stall);

    if_id_reg if_id (
        .clk               (clk),
        .rst               (rst),
        .load              (if_id_load),
        .bubble            (flush),
        .pc_in             (pc_out),
        .pc_plus_4_in      (pc_plus_4),
        .inst_in           (inst),
        .predicted_taken_in(predict_taken),
        .pc                (if_id_pc),
        .pc_plus_4         (if_id_pc_plus_4),
        .inst              (if_id_inst),
        .predicted_taken   (if_id_predicted_taken)
    );

    // ID Stage
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
    wire       halt;

    control_unit cu (
        .inst     (if_id_inst),
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
        .halt     (halt)
    );

    wire [31:0] imm;

    immediate_gen imm_gen (
        .inst(if_id_inst),
        .imm (imm)
    );

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [4:0]  rd;
    wire [4:0]  rs1;
    wire [4:0]  rs2;
    wire [2:0]  funct3;

    assign rd     = if_id_inst[`IR_rd];
    assign rs1    = if_id_inst[`IR_rs1];
    assign rs2    = if_id_inst[`IR_rs2];
    assign funct3 = if_id_inst[`IR_funct3];

    reg_file rf (
        .clk         (clk),
        .rst         (rst),
        .write_enable(mem_wb_c_reg_write),
        .read_addr_1 (rs1),
        .read_addr_2 (rs2),
        .write_addr  (mem_wb_rd),
        .write_data  (wb_data),
        .read_data_1 (rs1_data),
        .read_data_2 (rs2_data)
    );

    // Load-use + single-port memory hazard detection.
    hazard_unit hu (
        .id_ex_rd          (id_ex_rd),
        .id_ex_c_mem_read  (id_ex_c_mem_read),
        .if_id_rs1         (rs1),
        .if_id_rs2         (rs2),
        .ex_mem_c_mem_read (ex_mem_c_mem_read),
        .ex_mem_c_mem_write(ex_mem_c_mem_write),
        .stall             (stall)
    );

    // ID/EX Pipeline Register
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_pc_plus_4;
    wire [31:0] id_ex_rs1_data;
    wire [31:0] id_ex_rs2_data;
    wire [31:0] id_ex_imm;
    wire [4:0]  id_ex_rd;
    wire [4:0]  id_ex_rs1;
    wire [4:0]  id_ex_rs2;
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
    wire        id_ex_predicted_taken;

    id_ex_reg id_ex (
        .clk            (clk),
        .rst            (rst),
        .bubble         (stall | flush),

        .pc_in             (if_id_pc),
        .pc_plus_4_in      (if_id_pc_plus_4),
        .rs1_data_in       (rs1_data),
        .rs2_data_in       (rs2_data),
        .imm_in            (imm),
        .rd_in             (rd),
        .rs1_in            (rs1),
        .rs2_in            (rs2),
        .funct3_in         (funct3),
        .alu_sel_in        (alu_sel),
        .alu_src_a_in      (alu_src_a),
        .alu_src_b_in      (alu_src_b),
        .c_branch_in       (c_branch),
        .c_jump_in         (c_jump),
        .c_jalr_in         (c_jalr),
        .c_mem_read_in     (c_mem_read),
        .c_mem_write_in    (c_mem_write),
        .wb_src_in         (wb_src),
        .c_reg_write_in    (c_reg_write),
        .halt_in           (halt),
        .predicted_taken_in(if_id_predicted_taken),

        .pc             (id_ex_pc),
        .pc_plus_4      (id_ex_pc_plus_4),
        .rs1_data       (id_ex_rs1_data),
        .rs2_data       (id_ex_rs2_data),
        .imm            (id_ex_imm),
        .rd             (id_ex_rd),
        .rs1            (id_ex_rs1),
        .rs2            (id_ex_rs2),
        .funct3         (id_ex_funct3),
        .alu_sel        (id_ex_alu_sel),
        .alu_src_a      (id_ex_alu_src_a),
        .alu_src_b      (id_ex_alu_src_b),
        .c_branch       (id_ex_c_branch),
        .c_jump         (id_ex_c_jump),
        .c_jalr         (id_ex_c_jalr),
        .c_mem_read     (id_ex_c_mem_read),
        .c_mem_write    (id_ex_c_mem_write),
        .wb_src         (id_ex_wb_src),
        .c_reg_write    (id_ex_c_reg_write),
        .halt           (id_ex_halt),
        .predicted_taken(id_ex_predicted_taken)
    );

    // EX Stage
    wire [1:0] forward_a;
    wire [1:0] forward_b;

    forwarding_unit fwd (
        .id_ex_rs1         (id_ex_rs1),
        .id_ex_rs2         (id_ex_rs2),
        .ex_mem_rd         (ex_mem_rd),
        .ex_mem_c_reg_write(ex_mem_c_reg_write),
        .mem_wb_rd         (mem_wb_rd),
        .mem_wb_c_reg_write(mem_wb_c_reg_write),
        .forward_a         (forward_a),
        .forward_b         (forward_b)
    );

    reg [31:0] rs1_fwd;
    reg [31:0] rs2_fwd;

    always @(*) begin
        case (forward_a)
            2'b00:   rs1_fwd = id_ex_rs1_data;
            2'b10:   rs1_fwd = ex_mem_alu_out;
            2'b01:   rs1_fwd = wb_data;
            default: rs1_fwd = id_ex_rs1_data;
        endcase
    end

    always @(*) begin
        case (forward_b)
            2'b00:   rs2_fwd = id_ex_rs2_data;
            2'b10:   rs2_fwd = ex_mem_alu_out;
            2'b01:   rs2_fwd = wb_data;
            default: rs2_fwd = id_ex_rs2_data;
        endcase
    end

    reg  [31:0] alu_a;
    wire [31:0] alu_b;

    always @(*) begin
        case (id_ex_alu_src_a)
            2'b00:   alu_a = rs1_fwd;
            2'b01:   alu_a = id_ex_pc;
            2'b10:   alu_a = 32'b0;
            default: alu_a = rs1_fwd;
        endcase
    end

    assign alu_b = id_ex_alu_src_b ? id_ex_imm : rs2_fwd;

    wire [31:0] alu_out;
    wire        flag_z;
    wire        flag_c;
    wire        flag_v;
    wire        flag_n;

    alu #(.N(32)) alu_unit (
        .a  (alu_a),
        .b  (alu_b),
        .sel(id_ex_alu_sel),
        .out(alu_out),
        .z  (flag_z),
        .c  (flag_c),
        .v  (flag_v),
        .n  (flag_n)
    );

    // pc + imm: branch / JAL target; MEM uses it as the redirect address.
    wire [31:0] pc_plus_imm;
    wire        pc_plus_imm_cout;

    ripple #(.N(32)) pc_add_imm (
        .a   (id_ex_pc),
        .b   (id_ex_imm),
        .cin (1'b0),
        .sum (pc_plus_imm),
        .cout(pc_plus_imm_cout)
    );

    // EX/MEM Pipeline Register
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
    wire [31:0] ex_mem_pc;
    wire        ex_mem_predicted_taken;

    ex_mem_reg ex_mem (
        .clk            (clk),
        .rst            (rst),
        .bubble         (flush),

        .pc_in             (id_ex_pc),
        .alu_out_in        (alu_out),
        .rs2_data_in       (rs2_fwd),
        .pc_plus_4_in      (id_ex_pc_plus_4),
        .pc_plus_imm_in    (pc_plus_imm),
        .rd_in             (id_ex_rd),
        .funct3_in         (id_ex_funct3),
        .c_mem_read_in     (id_ex_c_mem_read),
        .c_mem_write_in    (id_ex_c_mem_write),
        .wb_src_in         (id_ex_wb_src),
        .c_reg_write_in    (id_ex_c_reg_write),
        .halt_in           (id_ex_halt),
        .c_branch_in       (id_ex_c_branch),
        .c_jump_in         (id_ex_c_jump),
        .c_jalr_in         (id_ex_c_jalr),
        .flag_z_in         (flag_z),
        .flag_c_in         (flag_c),
        .flag_v_in         (flag_v),
        .flag_n_in         (flag_n),
        .predicted_taken_in(id_ex_predicted_taken),

        .pc             (ex_mem_pc),
        .alu_out        (ex_mem_alu_out),
        .rs2_data       (ex_mem_rs2_data),
        .pc_plus_4      (ex_mem_pc_plus_4),
        .pc_plus_imm    (ex_mem_pc_plus_imm),
        .rd             (ex_mem_rd),
        .funct3         (ex_mem_funct3),
        .c_mem_read     (ex_mem_c_mem_read),
        .c_mem_write    (ex_mem_c_mem_write),
        .wb_src         (ex_mem_wb_src),
        .c_reg_write    (ex_mem_c_reg_write),
        .halt           (ex_mem_halt),
        .c_branch       (ex_mem_c_branch),
        .c_jump         (ex_mem_c_jump),
        .c_jalr         (ex_mem_c_jalr),
        .flag_z         (ex_mem_flag_z),
        .flag_c         (ex_mem_flag_c),
        .flag_v         (ex_mem_flag_v),
        .flag_n         (ex_mem_flag_n),
        .predicted_taken(ex_mem_predicted_taken)
    );

    // MEM Stage
    wire [31:0] store_wdata;
    wire [3:0]  store_write_mask;
    wire [31:0] dmem_rdata;
    wire [31:0] load_out;

    store_unit su (
        .rs2_data  (ex_mem_rs2_data),
        .addr_low  (ex_mem_alu_out[1:0]),
        .funct3    (ex_mem_funct3),
        .mem_write (ex_mem_c_mem_write),
        .wdata     (store_wdata),
        .write_mask(store_write_mask)
    );

    load_unit lu (
        .word_in  (dmem_rdata),
        .addr_low (ex_mem_alu_out[1:0]),
        .funct3   (ex_mem_funct3),
        .load_out (load_out)
    );

    // Unified memory (single port). MEM owns the port when load/store is
    // active; hazard_unit stalls IF otherwise, so the two never collide.
    wire        mem_port_is_data;
    wire [31:0] mem_addr;
    wire [31:0] mem_rdata;

    assign mem_port_is_data = ex_mem_c_mem_read | ex_mem_c_mem_write;
    assign mem_addr         = mem_port_is_data ? ex_mem_alu_out : pc_out;

    memory mem_unit (
        .clk       (clk),
        .addr      (mem_addr),
        .wdata     (store_wdata),
        .write_mask(store_write_mask),
        .rdata     (mem_rdata)
    );

    assign inst       = mem_rdata;
    assign dmem_rdata = mem_rdata;

    // Branch resolution (moved here from EX).
    wire branch_taken;

    branch_unit bu (
        .branch(ex_mem_c_branch),
        .funct3(ex_mem_funct3),
        .z     (ex_mem_flag_z),
        .c     (ex_mem_flag_c),
        .v     (ex_mem_flag_v),
        .n     (ex_mem_flag_n),
        .taken (branch_taken)
    );

    pc_control_unit pcc (
        .ex_mem_c_branch       (ex_mem_c_branch),
        .ex_mem_c_jump         (ex_mem_c_jump),
        .ex_mem_c_jalr         (ex_mem_c_jalr),
        .ex_mem_predicted_taken(ex_mem_predicted_taken),
        .branch_taken          (branch_taken),
        .ex_mem_alu_out        (ex_mem_alu_out),
        .ex_mem_pc_plus_4      (ex_mem_pc_plus_4),
        .ex_mem_pc_plus_imm    (ex_mem_pc_plus_imm),
        .predict_taken         (predict_taken),
        .predict_target        (predict_target),
        .pc_plus_4             (pc_plus_4),
        .flush                 (flush),
        .pc_next               (pc_next)
    );

    // MEM/WB Pipeline Register
    wire [31:0] mem_wb_alu_out;
    wire [31:0] mem_wb_load_out;
    wire [31:0] mem_wb_pc_plus_4;
    wire [4:0]  mem_wb_rd;
    wire [1:0]  mem_wb_wb_src;
    wire        mem_wb_c_reg_write;
    wire        mem_wb_halt;

    mem_wb_reg mem_wb (
        .clk            (clk),
        .rst            (rst),

        .alu_out_in     (ex_mem_alu_out),
        .load_out_in    (load_out),
        .pc_plus_4_in   (ex_mem_pc_plus_4),
        .rd_in          (ex_mem_rd),
        .wb_src_in      (ex_mem_wb_src),
        .c_reg_write_in (ex_mem_c_reg_write),
        .halt_in        (ex_mem_halt),

        .alu_out        (mem_wb_alu_out),
        .load_out       (mem_wb_load_out),
        .pc_plus_4      (mem_wb_pc_plus_4),
        .rd             (mem_wb_rd),
        .wb_src         (mem_wb_wb_src),
        .c_reg_write    (mem_wb_c_reg_write),
        .halt           (mem_wb_halt)
    );

    // WB Stage
    reg [31:0] wb_data_r;

    always @(*) begin
        case (mem_wb_wb_src)
            2'b00:   wb_data_r = mem_wb_alu_out;
            2'b01:   wb_data_r = mem_wb_load_out;
            2'b10:   wb_data_r = mem_wb_pc_plus_4;
            default: wb_data_r = mem_wb_alu_out;
        endcase
    end

    assign wb_data = wb_data_r;

    // halting: any halt in the pipe -> freeze fetch so no garbage runs
    // ahead while earlier instructions drain.
    // halted: the halt has reached WB -> every earlier instruction has
    // committed (testbench signal).
    assign halting = halt | id_ex_halt | ex_mem_halt | mem_wb_halt;
    assign halted  = mem_wb_halt;

endmodule
