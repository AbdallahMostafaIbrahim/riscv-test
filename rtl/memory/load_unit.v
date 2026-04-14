/*******************************************************************
*
* Module: load_unit.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Combinational load formatter. Extracts the byte or
*              halfword selected by addr[1:0] from the 32-bit word
*              returned by data_mem and performs the requested
*              sign- or zero-extension.
*
*              funct3:
*                  000 - LB    byte at addr_lo,   sign-extended
*                  001 - LH    half at addr[1],   sign-extended
*                  010 - LW    word (addr_lo ignored)
*                  100 - LBU   byte at addr_lo,   zero-extended
*                  101 - LHU   half at addr[1],   zero-extended
*
* Change history: 2026-04-14 - MS2: initial version.
*
**********************************************************************/
`timescale 1ns / 1ps

module load_unit (
    input      [31:0] word_in,
    input      [1:0]  addr_lo,
    input      [2:0]  funct3,
    output reg [31:0] load_out
);

    reg  [7:0]  byte_sel;
    reg  [15:0] half_sel;

    always @(*) begin
        // Default selections so every code path drives these regs.
        byte_sel = 8'b0;
        half_sel = 16'b0;
        load_out = 32'b0;

        case (addr_lo)
            2'b00:   byte_sel = word_in[ 7: 0];
            2'b01:   byte_sel = word_in[15: 8];
            2'b10:   byte_sel = word_in[23:16];
            2'b11:   byte_sel = word_in[31:24];
            default: byte_sel = 8'b0;
        endcase

        if (addr_lo[1] == 1'b0)
            half_sel = word_in[15:0];
        else
            half_sel = word_in[31:16];

        case (funct3)
            3'b000:  load_out = { {24{byte_sel[7]}},  byte_sel };   // LB
            3'b001:  load_out = { {16{half_sel[15]}}, half_sel };   // LH
            3'b010:  load_out = word_in;                            // LW
            3'b100:  load_out = { 24'b0, byte_sel };                // LBU
            3'b101:  load_out = { 16'b0, half_sel };                // LHU
            default: load_out = 32'b0;
        endcase
    end

endmodule
