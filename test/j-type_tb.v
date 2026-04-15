/*******************************************************************
*
* Module: j-type_tb.v
* Project: RISCV Processor
* Description: Testbench for tests/j-type.s. Verifies JAL and JALR:
*                  x1 = link address from JAL  (pc+4 = 0x04)
*                  x2 = 2 (jal landed past the poison)
*                  x3 = link address from JALR (pc+4 = 0x18)
*                  x4 = 4 (jalr landed past the poison)
*
**********************************************************************/
`timescale 1ns / 1ps

module j_type_tb;

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

        check_reg(5'd1,  32'h00000004, "jal_link    ");
        check_reg(5'd2,  32'h00000002, "jal_landed  ");
        check_reg(5'd3,  32'h00000018, "jalr_link   ");
        check_reg(5'd4,  32'h00000004, "jalr_landed ");
        check_reg(5'd10, 32'h00000000, "poison_skip ");  // both poisons skipped

        if (errors == 0)
            $display("==== j-type_tb: ALL TESTS PASSED (%0d cycles) ====",
                     cycles);
        else
            $display("==== j-type_tb: %0d TEST(S) FAILED (%0d cycles) ====",
                     errors, cycles);

        $finish;
    end

endmodule
