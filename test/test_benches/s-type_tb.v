/*******************************************************************
*
* Module: s-type_tb.v
* Project: RISCV Processor
* Description: Testbench for tests/s-type.s. Each store targets a
*              different dmem word so we can verify them
*              independently.
*
**********************************************************************/
`timescale 1ns / 1ps

module s_type_tb;

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

    task check_word;
        input integer    word_idx;
        input [31:0]     expected;
        input [12*8-1:0] name;
        begin
            if (dut.mem_unit.mem[word_idx] !== expected) begin
                $display("FAIL %0s: dmem[%0d] expected %08h got %08h",
                         name, word_idx, expected,
                         dut.mem_unit.mem[word_idx]);
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

        while (dut.halted === 1'b0 && cycles < 2000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (dut.halted === 1'b1)
            $display("HALT reached at cycle %0d (PC = %08h)",
                     cycles, dut.pc_out);
        else
            $display("TIMEOUT after %0d cycles (PC = %08h)",
                     cycles, dut.pc_out);

        // Data base is 0x400 => word 256. sw @ 0(x28), sh @ 4(x28),
        // sb @ 8(x28) land at mem[256], mem[257], mem[258].
        check_word(256, 32'h00000008, "sw");
        check_word(257, 32'h0000FFFF, "sh");
        check_word(258, 32'h00000008, "sb");

        if (errors == 0)
            $display("==== s-type_tb: ALL TESTS PASSED (%0d cycles) ====",
                     cycles);
        else
            $display("==== s-type_tb: %0d TEST(S) FAILED (%0d cycles) ====",
                     errors, cycles);

        $finish;
    end

endmodule
