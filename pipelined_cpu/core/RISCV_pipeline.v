`timescale 1ns / 1ps
`include "defines.v"

module RISCV_pipeline (
    input clk,
    input rst
);

    // ===================== IF stage =====================
    wire [31:0] pc_out;
    wire [31:0] pc_in;
    wire [31:0] pc_plus_4;
    wire        pc_plus_4_cout;

    register #(.N(32)) PC (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   (pc_in),
        .q   (pc_out)
    );

    ripple #(.N(32)) pc_add_4 (
        .a   (pc_out),
        .b   (32'd4),
        .cin (1'b0),
        .sum (pc_plus_4),
        .cout(pc_plus_4_cout)
    );

    wire [31:0] instruction;
    inst_mem imem (
        .addr    (pc_out),
        .data_out(instruction)
    );

    // ------- IF/ID pipeline register (64 bits: PC | Inst) -------
    wire [31:0] IF_ID_PC, IF_ID_Inst;
    wire [63:0] IF_ID_q;

    register #(.N(64)) IF_ID (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   ({pc_out, instruction}),
        .q   (IF_ID_q)
    );

    assign IF_ID_PC   = IF_ID_q[63:32];
    assign IF_ID_Inst = IF_ID_q[31:0];

    // ===================== ID stage =====================
    wire [7:0] id_ctrl;
    control_unit cu (
        .inst(IF_ID_Inst),
        .ctrl(id_ctrl)
    );

    wire [31:0] id_imm;
    immediate_gen imm_gen (
        .inst(IF_ID_Inst),
        .imm (id_imm)
    );

    wire [31:0] rs1_data, rs2_data;
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    reg_file rf (
        .clk         (clk),
        .rst         (rst),
        .write_enable(wb_reg_write),
        .read_addr_1 (IF_ID_Inst[`IR_rs1]),
        .read_addr_2 (IF_ID_Inst[`IR_rs2]),
        .write_addr  (wb_rd),
        .write_data  (wb_data),
        .read_data_1 (rs1_data),
        .read_data_2 (rs2_data)
    );

    wire [3:0] id_func = {IF_ID_Inst[30], IF_ID_Inst[`IR_funct3]};
    wire [4:0] id_rs1  = IF_ID_Inst[`IR_rs1];
    wire [4:0] id_rs2  = IF_ID_Inst[`IR_rs2];
    wire [4:0] id_rd   = IF_ID_Inst[`IR_rd];

    // ------- ID/EX pipeline register (155 bits) -------
    wire [7:0]  ID_EX_Ctrl;
    wire [31:0] ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm;
    wire [3:0]  ID_EX_Func;
    wire [4:0]  ID_EX_Rs1, ID_EX_Rs2, ID_EX_Rd;
    wire [154:0] ID_EX_q;

    register #(.N(155)) ID_EX (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   ({id_ctrl, IF_ID_PC, rs1_data, rs2_data,
               id_imm, id_func, id_rs1, id_rs2, id_rd}),
        .q   (ID_EX_q)
    );

    assign ID_EX_Ctrl  = ID_EX_q[154:147];
    assign ID_EX_PC    = ID_EX_q[146:115];
    assign ID_EX_RegR1 = ID_EX_q[114:83];
    assign ID_EX_RegR2 = ID_EX_q[82:51];
    assign ID_EX_Imm   = ID_EX_q[50:19];
    assign ID_EX_Func  = ID_EX_q[18:15];
    assign ID_EX_Rs1   = ID_EX_q[14:10];
    assign ID_EX_Rs2   = ID_EX_q[9:5];
    assign ID_EX_Rd    = ID_EX_q[4:0];

    // ===================== EX stage =====================
    wire       ex_alu_src  = ID_EX_Ctrl[0];
    wire [1:0] ex_alu_op   = ID_EX_Ctrl[2:1];

    wire [1:0] ex_alu_sel;
    alu_control ac (
        .alu_op (ex_alu_op),
        .func   (ID_EX_Func),
        .alu_sel(ex_alu_sel)
    );

    wire [31:0] ex_alu_b = ex_alu_src ? ID_EX_Imm : ID_EX_RegR2;

    wire [31:0] ex_alu_out;
    wire        ex_zero;

    alu #(.N(32)) alu_unit (
        .a  (ID_EX_RegR1),
        .b  (ex_alu_b),
        .sel(ex_alu_sel),
        .out(ex_alu_out),
        .z  (ex_zero)
    );

    wire [31:0] ex_branch_add_out;
    wire        ex_branch_add_cout;

    ripple #(.N(32)) branch_adder (
        .a   (ID_EX_PC),
        .b   (ID_EX_Imm),
        .cin (1'b0),
        .sum (ex_branch_add_out),
        .cout(ex_branch_add_cout)
    );

    // ------- EX/MEM pipeline register (107 bits) -------
    // Ctrl carries over WB+MEM signals only (ALUOp/ALUSrc dropped).
    wire [4:0] ex_mem_ctrl_in = ID_EX_Ctrl[7:3];

    wire [4:0]  EX_MEM_Ctrl;
    wire [31:0] EX_MEM_BranchAddOut, EX_MEM_ALU_out, EX_MEM_RegR2;
    wire        EX_MEM_Zero;
    wire [4:0]  EX_MEM_Rd;
    wire [106:0] EX_MEM_q;

    register #(.N(107)) EX_MEM (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   ({ex_mem_ctrl_in, ex_branch_add_out, ex_zero,
               ex_alu_out, ID_EX_RegR2, ID_EX_Rd}),
        .q   (EX_MEM_q)
    );

    assign EX_MEM_Ctrl         = EX_MEM_q[106:102];
    assign EX_MEM_BranchAddOut = EX_MEM_q[101:70];
    assign EX_MEM_Zero         = EX_MEM_q[69];
    assign EX_MEM_ALU_out      = EX_MEM_q[68:37];
    assign EX_MEM_RegR2        = EX_MEM_q[36:5];
    assign EX_MEM_Rd           = EX_MEM_q[4:0];

    // ===================== MEM stage =====================
    wire mem_mem_write = EX_MEM_Ctrl[0];
    wire mem_mem_read  = EX_MEM_Ctrl[1];
    wire mem_branch    = EX_MEM_Ctrl[2];

    wire [31:0] mem_rdata;
    data_mem dmem (
        .clk      (clk),
        .mem_read (mem_mem_read),
        .mem_write(mem_mem_write),
        .addr     (EX_MEM_ALU_out),
        .wdata    (EX_MEM_RegR2),
        .rdata    (mem_rdata)
    );

    wire pc_src = mem_branch & EX_MEM_Zero;
    assign pc_in = pc_src ? EX_MEM_BranchAddOut : pc_plus_4;

    // ------- MEM/WB pipeline register (71 bits) -------
    wire [1:0] mem_wb_ctrl_in = EX_MEM_Ctrl[4:3];

    wire [1:0]  MEM_WB_Ctrl;
    wire [31:0] MEM_WB_Mem_out, MEM_WB_ALU_out;
    wire [4:0]  MEM_WB_Rd;
    wire [70:0] MEM_WB_q;

    register #(.N(71)) MEM_WB (
        .clk (clk),
        .rst (rst),
        .load(1'b1),
        .d   ({mem_wb_ctrl_in, mem_rdata, EX_MEM_ALU_out, EX_MEM_Rd}),
        .q   (MEM_WB_q)
    );

    assign MEM_WB_Ctrl    = MEM_WB_q[70:69];
    assign MEM_WB_Mem_out = MEM_WB_q[68:37];
    assign MEM_WB_ALU_out = MEM_WB_q[36:5];
    assign MEM_WB_Rd      = MEM_WB_q[4:0];

    // ===================== WB stage =====================
    wire wb_mem_to_reg = MEM_WB_Ctrl[0];
    assign wb_reg_write = MEM_WB_Ctrl[1];
    assign wb_rd        = MEM_WB_Rd;
    assign wb_data      = wb_mem_to_reg ? MEM_WB_Mem_out : MEM_WB_ALU_out;

endmodule
