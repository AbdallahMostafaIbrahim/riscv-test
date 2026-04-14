/*******************************************************************
*
* Module: riscv_tb.v
* Project: femtoRV32
* Author: CSCE 3301 Team
* Description: End-to-end integration testbench for the single-cycle
*              RV32I core. Loads mem/inst.hex via the CPU's instruction
*              memory, runs until the sticky halted flag is asserted
*              (with a cycle cap), and checks a curated set of
*              register and memory values against their expected
*              post-state. Covers every supported instruction class.
*
* Change history: 2026-04-14 - MS2: initial integration testbench.
*
**********************************************************************/
`timescale 1ns / 1ps

module riscv_tb;

    reg clk;
    reg rst;

    integer cycles;
    integer errors;

    riscv dut (
        .clk(clk),
        .rst(rst)
    );

    // -----------------------------------------------------------------
    // Clock: 10 ns period.
    // -----------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

`ifdef DUMP_VCD
    initial begin
        $dumpfile("build/dump.vcd");
        $dumpvars(0, riscv_tb);
    end
`endif

    // -----------------------------------------------------------------
    // Checker task: compare a register-file entry against an expected
    // value and bump the error counter on mismatch.
    // -----------------------------------------------------------------
    task check_reg;
        input [4:0]  idx;
        input [31:0] expected;
        input [8*8-1:0] name;
        begin
            if (dut.rf.regs[idx] !== expected) begin
                $display("FAIL %0s: x%0d expected %08h got %08h",
                         name, idx, expected, dut.rf.regs[idx]);
                errors = errors + 1;
            end
            else begin
                $display("PASS %0s: x%0d = %08h", name, idx, expected);
            end
        end
    endtask

    task check_word;
        input integer word_idx;
        input [31:0]  expected;
        input [8*8-1:0] name;
        begin
            if (dut.dmem.mem[word_idx] !== expected) begin
                $display("FAIL %0s: dmem[%0d] expected %08h got %08h",
                         name, word_idx, expected, dut.dmem.mem[word_idx]);
                errors = errors + 1;
            end
            else begin
                $display("PASS %0s: dmem[%0d] = %08h",
                         name, word_idx, expected);
            end
        end
    endtask

    // -----------------------------------------------------------------
    // Main stimulus
    // -----------------------------------------------------------------
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

        // --------------- register checks -------------------------
        check_reg(5'd1,  32'h00000005, "addi1");
        check_reg(5'd2,  32'h00000003, "addi2");
        check_reg(5'd3,  32'h00000008, "add ");
        check_reg(5'd4,  32'h00000002, "sub ");
        check_reg(5'd5,  32'h00000001, "and ");
        check_reg(5'd6,  32'h00000007, "or  ");
        check_reg(5'd7,  32'h00000006, "xor ");
        check_reg(5'd8,  32'h00000014, "slli");
        check_reg(5'd9,  32'h0000000a, "srli");
        check_reg(5'd10, 32'h00000001, "srai");
        check_reg(5'd11, 32'h00000001, "slt ");
        check_reg(5'd12, 32'h00000001, "sltu");
        check_reg(5'd13, 32'habcde000, "lui ");
        check_reg(5'd14, 32'h00001034, "auip");
        check_reg(5'd15, 32'h00000008, "lw  ");
        check_reg(5'd16, 32'h00000007, "lb  ");
        check_reg(5'd17, 32'h00000006, "lh  ");
        check_reg(5'd18, 32'h00000000, "bskp");
        check_reg(5'd19, 32'h0000002a, "bok ");
        check_reg(5'd20, 32'h00000000, "bnskp");
        check_reg(5'd21, 32'h0000004d, "bnok");
        check_reg(5'd22, 32'h0000006c, "jall");
        check_reg(5'd23, 32'h00000000, "jskp");
        check_reg(5'd24, 32'h00000037, "jdst");
        check_reg(5'd25, 32'h00000028, "sll ");
        check_reg(5'd26, 32'h00000002, "srl ");
        check_reg(5'd27, 32'h00000000, "sra ");
        // For BLT/BGE/BLTU we check that the "if not taken" addi was
        // skipped -- the target register should still hold its reset
        // value (0) because nothing writes to it unless the branch
        // falls through.
        check_reg(5'd28, 32'h00000000, "blt ");
        check_reg(5'd29, 32'h00000000, "bge ");
        check_reg(5'd30, 32'h00000000, "bltu");
        // BGEU skips an addi that would otherwise set x5 = 99,
        // so x5 should still hold the value produced earlier by AND.
        check_reg(5'd5,  32'h00000001, "bgeu");
        // JALR writes PC+4 of its own instruction (0xb4) to x31
        // and jumps to (x31 + 8) & ~1 = 0xb8.
        check_reg(5'd31, 32'h000000b8, "jalr");

        // --------------- memory checks ---------------------------
        // After SW x3, 0(x0): word 0 = 8.
        // Then SB x6,5(x0) and SH x7,6(x0) update word 1:
        //   byte 5 = 0x07 (from x6)
        //   bytes 6..7 = 0x0006 (halfword from x7)
        //   -> word 1 = 0x0006_07_00
        check_word(0, 32'h00000008, "mem0");
        check_word(1, 32'h00060700, "mem1");

        if (errors == 0)
            $display("==== ALL TESTS PASSED (%0d cycles) ====", cycles);
        else
            $display("==== %0d TEST(S) FAILED (%0d cycles) ====",
                     errors, cycles);

        $finish;
    end

endmodule
