/*******************************************************************
*
* Module: forward_tb.v
* Project: RISCV Processor
* Description: Testbench for test/asm/forward.s.
*
**********************************************************************/
`timescale 1ns / 1ps

module forward_tb;

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
        input [4:0]      idx;
        input [31:0]     expected;
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

        check_reg(5'd5,  32'd10, "chain1");
        check_reg(5'd6,  32'd15, "chain2");
        check_reg(5'd7,  32'd20, "chain3");
        check_reg(5'd8,  32'd25, "chain4");
        check_reg(5'd9,  32'd30, "chain5");

        check_reg(5'd10, 32'd100, "mw_src");
        check_reg(5'd11, 32'd101, "mw_use");

        check_reg(5'd30, 32'd55, "neg_src");
        check_reg(5'd3,  32'd1,  "neg_fill1");
        check_reg(5'd4,  32'd2,  "neg_fill2");
        check_reg(5'd31, 32'd56, "neg_use");

        check_reg(5'd15, 32'h000000AB, "sw_src");
        check_word(256,  32'h000000AB, "store_mem");
        check_reg(5'd16, 32'h000000AB, "lw_dest");
        check_reg(5'd17, 32'h000000AC, "load_use");

        check_reg(5'd20, 32'd7,  "br_a");
        check_reg(5'd21, 32'd7,  "br_b");
        check_reg(5'd23, 32'd88, "br_target");
        check_reg(5'd22, 32'd0,  "br_flush1");
        check_reg(5'd24, 32'd0,  "br_flush2");
        check_reg(5'd25, 32'd0,  "br_flush3");
        check_reg(5'd26, 32'd0,  "br_flush4");

        check_reg(5'd1,  32'h00000068, "jal_link");
        check_reg(5'd12, 32'd42, "jal_target");
        check_reg(5'd27, 32'd0,  "jal_flush1");
        check_reg(5'd28, 32'h00000400, "jal_flush2");
        check_reg(5'd29, 32'd0,  "jal_flush3");

        if (errors == 0)
            $display("==== forward_tb: ALL TESTS PASSED (%0d cycles) ====",
                     cycles);
        else
            $display("==== forward_tb: %0d TEST(S) FAILED (%0d cycles) ====",
                     errors, cycles);

        $finish;
    end

endmodule
