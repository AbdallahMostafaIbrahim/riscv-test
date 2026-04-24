`timescale 1ns / 1ps

module RISCV_pipeline_tb;

    reg clk;
    reg rst;

    RISCV_pipeline dut (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer i;

    initial begin
        $dumpfile("pipeline.vcd");
        $dumpvars(0, RISCV_pipeline_tb);

        rst = 1;
        #12;
        rst = 0;

        // 70 cycles should comfortably drain 50 instructions through
        // a 5-stage pipeline (50 + 4 fill cycles).
        #700;

        $display("========== Final register file ==========");
        for (i = 0; i < 10; i = i + 1) begin
            $display("  x%0d = %0d (0x%08h)", i, dut.rf.regs[i], dut.rf.regs[i]);
        end

        $display("========== Data memory [0..4] ==========");
        for (i = 0; i < 5; i = i + 1) begin
            $display("  dmem[%0d] = %0d (0x%08h)", i, dut.dmem.mem[i], dut.dmem.mem[i]);
        end

        $display("========== Expected results ==========");
        $display("  x1=17, x2=9, x3=25, x4=25, x5=34, x6=34, x7=0, x8=8, x9=17");
        $display("  dmem[3]=34");

        $finish;
    end

endmodule
