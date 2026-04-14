/*******************************************************************
*
* Module: fibonacci_tb.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: Testbench for tests/fibonacci.s. Runs the Fibonacci
*              program for 10 iterations starting from (fib(0)=0,
*              fib(1)=1), stores the final result to dmem[0], then
*              halts via EBREAK. Checks the end state.
*
*              Expected final values (10 iterations from 0,1):
*                  fib(10) = 55    -> x1   (prev)
*                  fib(11) = 89    -> x2   (curr)
*                                    -> x3   (result, also stored)
*                                    -> dmem[0]
*                  x4  = 0  (loop counter exhausted)
*
* Change history: 2026-04-15 - MS2: initial version.
*
**********************************************************************/
`timescale 1ns / 1ps

module fibonacci_tb;

    reg clk;
    reg rst;

    integer cycles;
    integer errors;

    riscv dut (
        .clk(clk),
        .rst(rst)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task check_reg;
        input [4:0]     idx;
        input [31:0]    expected;
        input [12*8-1:0] name;
        begin
            if (dut.rf.regs[idx] !== expected) begin
                $display("FAIL %0s: x%0d expected %08h got %08h",
                         name, idx, expected, dut.rf.regs[idx]);
                errors = errors + 1;
            end
            else begin
                $display("PASS %0s: x%0d = %08h",
                         name, idx, expected);
            end
        end
    endtask

    task check_word;
        input integer   word_idx;
        input [31:0]    expected;
        input [12*8-1:0] name;
        begin
            if (dut.dmem.mem[word_idx] !== expected) begin
                $display("FAIL %0s: dmem[%0d] expected %08h got %08h",
                         name, word_idx, expected,
                         dut.dmem.mem[word_idx]);
                errors = errors + 1;
            end
            else begin
                $display("PASS %0s: dmem[%0d] = %08h",
                         name, word_idx, expected);
            end
        end
    endtask

    initial begin
        rst    = 1'b1;
        cycles = 0;
        errors = 0;
        #20 rst = 1'b0;

        while (dut.halt_u.halted === 1'b0 && cycles < 2000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (dut.halt_u.halted === 1'b1)
            $display("HALT reached at cycle %0d (PC = %08h)",
                     cycles, dut.pc_out);
        else
            $display("TIMEOUT after %0d cycles (PC = %08h)",
                     cycles, dut.pc_out);

        check_reg (5'd1,  32'd55, "fib_prev   ");
        check_reg (5'd2,  32'd89, "fib_curr   ");
        check_reg (5'd3,  32'd89, "fib_result ");
        check_reg (5'd4,  32'd0,  "loop_cnt   ");
        check_word(0,     32'd89, "mem_stored ");

        if (errors == 0)
            $display("==== fibonacci_tb: ALL TESTS PASSED (%0d cycles) ====",
                     cycles);
        else
            $display("==== fibonacci_tb: %0d TEST(S) FAILED (%0d cycles) ====",
                     errors, cycles);

        $finish;
    end

endmodule
