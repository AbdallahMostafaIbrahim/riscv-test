/*******************************************************************
*
* Module: store_unit.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Combinational store formatter. Converts the store
*              instruction's funct3, the low two bits of the byte
*              address, and rs2_data into a 32-bit `wdata` lined up
*              for the correct byte lane plus a 4-bit per-byte
*              `write_mask` for data_mem.
*
*              When mem_write is low the output write_mask is forced to
*              all zeros so no lane is written.
*
*              funct3:
*                  000 - SB   one byte  at addr_low
*                  001 - SH   halfword  at addr[1]
*                  010 - SW   full word (addr_low ignored)
*
* Change history: 2026-04-14 - MS2: initial version.
*
**********************************************************************/
`timescale 1ns / 1ps
`include "defines.v"

module store_unit (
    input      [31:0] rs2_data,
    input      [1:0]  addr_low,
    input      [2:0]  funct3,
    input             mem_write,
    output reg [31:0] wdata,
    output reg [3:0]  write_mask
);

    always @(*) begin
        wdata = 32'b0;
        write_mask = 4'b0000;

        if (mem_write) begin
            case (funct3)
                `F3_SB: begin
                    // SB: replicate byte into every lane, then
                    //     enable only the target lane.
                    wdata = { rs2_data[7:0], rs2_data[7:0],
                              rs2_data[7:0], rs2_data[7:0] };
                    case (addr_low)
                        2'b00:   write_mask = 4'b0001;
                        2'b01:   write_mask = 4'b0010;
                        2'b10:   write_mask = 4'b0100;
                        2'b11:   write_mask = 4'b1000;
                        default: write_mask = 4'b0000;
                    endcase
                end

                `F3_SH: begin
                    // SH: place halfword in the upper or lower
                    //     half depending on addr[1].
                    if (addr_low[1] == 1'b0) begin
                        wdata = { 16'b0, rs2_data[15:0] };
                        write_mask = 4'b0011;
                    end
                    else begin
                        wdata = { rs2_data[15:0], 16'b0 };
                        write_mask = 4'b1100;
                    end
                end

                `F3_SW: begin
                    wdata = rs2_data;
                    write_mask = 4'b1111;
                end

                default: begin
                    wdata = 32'b0;
                    write_mask = 4'b0000;
                end
            endcase
        end
        else begin
            wdata = 32'b0;
            write_mask = 4'b0000;
        end
    end

endmodule
