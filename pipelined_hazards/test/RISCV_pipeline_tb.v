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
    integer stall_count = 0;

    always @(posedge clk) begin
        if (!rst && dut.stall)
            stall_count = stall_count + 1;
    end

    initial begin
        $dumpfile("pipeline.vcd");
        $dumpvars(0, RISCV_pipeline_tb);

        rst = 1;
        #12;
        rst = 0;

        // 30 cycles: 17 instructions + 5-stage fill + margin.
        #300;

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
        $display("  stalls observed = %0d (expected 1 for lw x6 -> and x7)", stall_count);

        $finish;
    end

endmodule
