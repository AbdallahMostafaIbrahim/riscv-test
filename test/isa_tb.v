/*******************************************************************
*
* Module: isa_tb.v
* Project: RISCV Processor
* Author: Arch Island
* Description: Table-driven per-instruction testbench. For each
*              case the testbench pulses reset, pre-loads the
*              register file and a data-memory cell with known
*              values via hierarchical reference, places the
*              instruction under test at PC = 0 followed by EBREAK
*              at PC = 4, then clocks the CPU until halted. The
*              cases below cover corner behaviors that the
*              integration testbench does not directly exercise
*              (negative immediates, SLTI/SLTIU against negative
*              and zero values, SRA with a set MSB, and the
*              zero-extending loads LBU / LHU).
*
* Change history: 2026-04-14 - MS2: initial version.
*
**********************************************************************/
`timescale 1ns / 1ps

module isa_tb;

    reg clk;
    reg rst;

    integer passes;
    integer errors;
    integer i;
    integer cycles;

    reg [31:0] case_inst;
    reg [31:0] case_x1;
    reg [31:0] case_x2;
    reg [31:0] case_mem0;
    reg [4:0]  case_rd;
    reg [31:0] case_expected;
    reg [16*8-1:0] case_name;

    riscv dut (
        .clk(clk),
        .rst(rst)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task run_current_case;
        begin
            // Phase 1 - assert reset on a negedge so the next
            // posedge does a clean async clear of all state.
            @(negedge clk);
            rst = 1'b1;
            @(posedge clk);
            @(negedge clk);
            rst = 1'b0;

            // Phase 2 - pre-load state. Reset is de-asserted, we
            // are between a negedge and a posedge, and no posedge
            // will re-clear the register file until after the
            // pokes below take effect.
            for (i = 0; i < 32; i = i + 1)
                dut.rf.regs[i] = 32'h0;
            dut.rf.regs[1] = case_x1;
            dut.rf.regs[2] = case_x2;

            dut.imem.mem[0] = case_inst;
            dut.imem.mem[1] = 32'h00100073;     // ebreak
            dut.dmem.mem[0] = case_mem0;

            // Phase 3 - clock until halted (with a cap).
            cycles = 0;
            while (dut.halted === 1'b0 && cycles < 200) begin
                @(posedge clk);
                cycles = cycles + 1;
            end

            // Phase 4 - check.
            if (dut.rf.regs[case_rd] !== case_expected) begin
                $display("FAIL %0s: expected %08h got %08h (cycles=%0d)",
                         case_name, case_expected,
                         dut.rf.regs[case_rd], cycles);
                errors = errors + 1;
            end
            else begin
                $display("PASS %0s: %08h (cycles=%0d)",
                         case_name, case_expected, cycles);
                passes = passes + 1;
            end
        end
    endtask

    initial begin
        rst    = 1'b1;
        passes = 0;
        errors = 0;

        // ADDI with negative immediate: 10 + (-5) = 5
        case_inst     = 32'hffb08193;   // addi x3, x1, -5
        case_x1       = 32'd10;
        case_x2       = 32'd0;
        case_mem0     = 32'd0;
        case_rd       = 5'd3;
        case_expected = 32'h00000005;
        case_name     = "addi_neg";
        run_current_case();

        // XORI with -1 inverts every bit
        case_inst     = 32'hfff0c193;   // xori x3, x1, -1
        case_x1       = 32'h00ff00ff;
        case_expected = 32'hff00ff00;
        case_name     = "xori_inv";
        run_current_case();

        // SLTI of -1 vs 0 (signed) -> 1
        case_inst     = 32'h0000a193;   // slti x3, x1, 0
        case_x1       = 32'hffffffff;
        case_expected = 32'h00000001;
        case_name     = "slti_neg";
        run_current_case();

        // SLTIU of 0 vs 1 (unsigned) -> 1
        case_inst     = 32'h0010b193;   // sltiu x3, x1, 1
        case_x1       = 32'h00000000;
        case_expected = 32'h00000001;
        case_name     = "sltiu_zro";
        run_current_case();

        // SRAI of negative by 4 keeps the sign
        case_inst     = 32'h4040d193;   // srai x3, x1, 4
        case_x1       = 32'hffffff00;
        case_expected = 32'hfffffff0;
        case_name     = "srai_neg";
        run_current_case();

        // SRA register-register with MSB set: 0x80000000 >>> 1
        case_inst     = 32'h4020d1b3;   // sra x3, x1, x2
        case_x1       = 32'h80000000;
        case_x2       = 32'd1;
        case_expected = 32'hc0000000;
        case_name     = "sra_msb ";
        run_current_case();

        // LBU zero-extends when the byte has MSB set
        case_inst     = 32'h00004183;   // lbu x3, 0(x0)
        case_x1       = 32'd0;
        case_x2       = 32'd0;
        case_mem0     = 32'hffffff80;
        case_expected = 32'h00000080;
        case_name     = "lbu_zx  ";
        run_current_case();

        // LHU zero-extends a halfword with the sign bit set
        case_inst     = 32'h00005183;   // lhu x3, 0(x0)
        case_mem0     = 32'hffff8000;
        case_expected = 32'h00008000;
        case_name     = "lhu_zx  ";
        run_current_case();

        // LH sign-extends the same halfword
        case_inst     = 32'h00001183;   // lh x3, 0(x0)
        case_expected = 32'hffff8000;
        case_name     = "lh_sx   ";
        run_current_case();

        if (errors == 0)
            $display("==== isa_tb: ALL %0d TESTS PASSED ====", passes);
        else
            $display("==== isa_tb: %0d PASS, %0d FAIL ====",
                     passes, errors);

        $finish;
    end

endmodule
