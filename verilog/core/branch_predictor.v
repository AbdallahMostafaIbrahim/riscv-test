/*******************************************************************
*
* Module: branch_predictor.v
* Project: riscv32Project
* Description: IF-stage predictor for conditional branches only
*              (JAL/JALR remain unpredicted). Direct-mapped 64-entry
*              BHT (2-bit saturating counters, reset to weakly-NT)
*              and BTB ({valid, tag, target}), both indexed by
*              PC[7:2]. Predict taken iff BHT MSB is 1 and BTB hits.
*              BTB entries are allocated only on taken resolutions.
*
**********************************************************************/
`timescale 1ns / 1ps

module branch_predictor (
    input         clk,
    input         rst,

    // IF-stage lookup (combinational)
    input  [31:0] pc_if,
    output        predict_taken,
    output [31:0] predict_target,

    // MEM-stage update (synchronous)
    input         update_valid,
    input  [31:0] update_pc,
    input         update_taken,
    input  [31:0] update_target
);

    localparam IDX_W = 6;    // 64 entries
    localparam TAG_W = 24;   // PC[31:8]
    localparam N_ENT = 1 << IDX_W;

    reg [1:0]        bht       [0:N_ENT-1];
    reg              btb_valid [0:N_ENT-1];
    reg [TAG_W-1:0]  btb_tag   [0:N_ENT-1];
    reg [31:0]       btb_target[0:N_ENT-1];

    // Lookup (IF)
    wire [IDX_W-1:0] read_idx;
    wire [TAG_W-1:0] read_tag;

    assign read_idx = pc_if[IDX_W+1:2];
    assign read_tag = pc_if[31:IDX_W+2];

    wire btb_hit;
    assign btb_hit = btb_valid[read_idx] & (btb_tag[read_idx] == read_tag);

    assign predict_taken  = bht[read_idx][1] & btb_hit;
    assign predict_target = btb_target[read_idx];

    // Update (MEM)
    wire [IDX_W-1:0] write_idx;
    wire [TAG_W-1:0] write_tag;

    assign write_idx = update_pc[IDX_W+1:2];
    assign write_tag = update_pc[31:IDX_W+2];

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < N_ENT; i = i + 1) begin
                bht[i]        <= 2'b01;
                btb_valid[i]  <= 1'b0;
                btb_tag[i]    <= {TAG_W{1'b0}};
                btb_target[i] <= 32'b0;
            end
        end
        else if (update_valid) begin
            // 2-bit saturating counter
            case (bht[write_idx])
                2'b00: bht[write_idx] <= update_taken ? 2'b01 : 2'b00;
                2'b01: bht[write_idx] <= update_taken ? 2'b10 : 2'b00;
                2'b10: bht[write_idx] <= update_taken ? 2'b11 : 2'b01;
                2'b11: bht[write_idx] <= update_taken ? 2'b11 : 2'b10;
            endcase

            // Allocate BTB only on taken
            if (update_taken) begin
                btb_valid[write_idx]  <= 1'b1;
                btb_tag[write_idx]    <= write_tag;
                btb_target[write_idx] <= update_target;
            end
        end
    end

endmodule
