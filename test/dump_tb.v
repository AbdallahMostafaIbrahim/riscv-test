/*******************************************************************
*
* Module: dump_tb.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Generic testbench for ad-hoc programs. Runs the core
*              from reset until the halted flag rises (or a cycle
*              cap expires), then prints the final PC and the full
*              register file as a hex dump. No hard-coded expected
*              values -- use this when you want to try a custom
*              program and eyeball the result.
*
*              The instruction memory is loaded from "inst.hex" in
*              the simulator's working directory (same convention as
*              riscv_tb.v). The Makefile's `make run PROG=foo`
*              target copies tests/foo.hex into mem/inst.hex before
*              invoking the sim.
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

`ifdef DUMP_VCD
    initial begin
        $dumpfile("../build/dump.vcd");
        $dumpvars(0, dump_tb);
    end
`endif

    initial begin
        rst    = 1'b1;
        cycles = 0;
        #20 rst = 1'b0;

        while (dut.halt_u.halted === 1'b0 && cycles < 5000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (dut.halt_u.halted === 1'b1)
            $display("HALT at cycle %0d, PC = %08h", cycles, dut.pc_out);
        else
            $display("TIMEOUT after %0d cycles, PC = %08h",
                     cycles, dut.pc_out);

        $display("------ register file ------");
        for (i = 0; i < 32; i = i + 1) begin
            $display("x%-2d = %08h", i, dut.rf.regs[i]);
        end

        $display("------ data memory (first 8 words) ------");
        for (i = 0; i < 8; i = i + 1) begin
            $display("dmem[%0d] = %08h", i, dut.dmem.mem[i]);
        end

        $finish;
    end

endmodule
