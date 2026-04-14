/*******************************************************************
*
* Module: store_unit.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Combinational store formatter. Converts the store
*              instruction's funct3, the low two bits of the byte
*              address, and rs2_data into a 32-bit `wdata` lined up
*              for the correct byte lane plus a 4-bit byte-write
*              strobe `wstrb` for data_mem.
*
*              When mem_write is low the output wstrb is forced to
*              all zeros so no lane is written.
*
*              funct3:
*                  000 - SB   one byte  at addr_lo
*                  001 - SH   halfword  at addr[1]
*                  010 - SW   full word (addr_lo ignored)
*
* Change history: 2026-04-14 - MS2: initial version.
*
**********************************************************************/
`timescale 1ns / 1ps

module store_unit (
    input      [31:0] rs2_data,
    input      [1:0]  addr_lo,
    input      [2:0]  funct3,
    input             mem_write,
    output reg [31:0] wdata,
    output reg [3:0]  wstrb
);

    always @(*) begin
        wdata = 32'b0;
        wstrb = 4'b0000;

        if (mem_write) begin
            case (funct3)
                3'b000: begin
                    // SB: replicate byte into every lane, then
                    //     enable only the target lane.
                    wdata = { rs2_data[7:0], rs2_data[7:0],
                              rs2_data[7:0], rs2_data[7:0] };
                    case (addr_lo)
                        2'b00:   wstrb = 4'b0001;
                        2'b01:   wstrb = 4'b0010;
                        2'b10:   wstrb = 4'b0100;
                        2'b11:   wstrb = 4'b1000;
                        default: wstrb = 4'b0000;
                    endcase
                end

                3'b001: begin
                    // SH: place halfword in the upper or lower
                    //     half depending on addr[1].
                    if (addr_lo[1] == 1'b0) begin
                        wdata = { 16'b0, rs2_data[15:0] };
                        wstrb = 4'b0011;
                    end
                    else begin
                        wdata = { rs2_data[15:0], 16'b0 };
                        wstrb = 4'b1100;
                    end
                end

                3'b010: begin
                    // SW: whole word.
                    wdata = rs2_data;
                    wstrb = 4'b1111;
                end

                default: begin
                    wdata = 32'b0;
                    wstrb = 4'b0000;
                end
            endcase
        end
        else begin
            wdata = 32'b0;
            wstrb = 4'b0000;
        end
    end

endmodule
