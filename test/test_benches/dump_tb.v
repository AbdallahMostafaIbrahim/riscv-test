/*******************************************************************
*
* Module: dump_tb.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Generic testbench for one-off programs 
*              that dumps register file and memory
*
* Change history: 2026-04-15 - MS2: initial version.
*
**********************************************************************/
`timescale 1ns / 1ps

module dump_tb;

    reg clk;
    reg rst;
    integer cycles;
    integer i;

    riscv dut (
        .clk(clk),
        .rst(rst)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        rst    = 1'b1;
        cycles = 0;
        #20 rst = 1'b0;

        while (dut.halted === 1'b0 && cycles < 5000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (dut.halted === 1'b1)
            $display("HALT at cycle %0d, PC = %08h", cycles, dut.pc_out);
        else
            $display("TIMEOUT after %0d cycles, PC = %08h",
                     cycles, dut.pc_out);

        $display("------ register file ------");
        for (i = 0; i < 32; i = i + 1) begin
            $display("x%-2d = %08h", i, dut.rf.regs[i]);
        end

        // Data region starts at word 256 (0x400). Dump 8 words
        // there so the testbench shows program-visible data, not
        // the program itself.
        $display("------ data memory (words 256..263, 0x400+) ------");
        for (i = 0; i < 8; i = i + 1) begin
            $display("dmem[%0d] = %08h", 256+i, dut.mem_unit.mem[256+i]);
        end

        $finish;
    end

endmodule
