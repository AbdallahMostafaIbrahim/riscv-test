/*******************************************************************
*
* Module: halt_unit.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Sticky halted flag. Goes high on the first clock edge
*              where `halt_in` is asserted and stays high until an
*              asynchronous reset. Used to freeze the program
*              counter and gate writes when ECALL / EBREAK / PAUSE /
*              FENCE / FENCE.TSO is decoded.
*
* Change history: 2026-04-14 - MS2: initial version.
*
**********************************************************************/
`timescale 1ns / 1ps

module halt_unit (
    input      clk,
    input      rst,
    input      halt_in,
    output reg halted
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            halted <= 1'b0;
        else if (halt_in)
            halted <= 1'b1;
        else
            halted <= halted;
    end

endmodule
