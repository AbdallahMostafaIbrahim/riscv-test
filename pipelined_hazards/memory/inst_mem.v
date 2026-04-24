`timescale 1ns / 1ps

// Minimized test program for Experiment 2 (forwarding + load-use stall).
// Remaining NOPs:
//   * 3 after BEQ (branch decided in MEM; no flushing yet).
// The load-use gap between lw x6 and and x7, x6, x1 is now handled by HDU.
module inst_mem (
    input  [31:0] addr,
    output [31:0] data_out
);

    reg [31:0] mem [0:1023];

    assign data_out = mem[addr[11:2]];

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 32'b0;

        mem[0]  = 32'b0000000_00000_00000_000_00000_0110011;   // add x0,x0,x0  (skipped)
        mem[1]  = 32'b000000000000_00000_010_00001_0000011;    // lw x1, 0(x0)
        mem[2]  = 32'b000000000100_00000_010_00010_0000011;    // lw x2, 4(x0)
        mem[3]  = 32'b000000001000_00000_010_00011_0000011;    // lw x3, 8(x0)
        mem[4]  = 32'b0000000_00010_00001_110_00100_0110011;   // or  x4, x1, x2   (fwd x2 from MEM/WB)
        mem[5]  = 32'b0_000000_00011_00100_000_1000_0_1100011; // beq x4, x3, +16 (fwd x4 from EX/MEM, x3 from MEM/WB)
        mem[6]  = 32'b0000000_00000_00000_000_00000_0110011;   // NOP (branch delay 1)
        mem[7]  = 32'b0000000_00000_00000_000_00000_0110011;   // NOP (branch delay 2)
        mem[8]  = 32'b0000000_00000_00000_000_00000_0110011;   // NOP (branch delay 3)
        mem[9]  = 32'b0000000_00010_00011_000_00101_0110011;   // add x5, x3, x2   (branch target)
        mem[10] = 32'b0000000_00101_00000_010_01100_0100011;   // sw  x5, 12(x0)   (fwd x5 from EX/MEM)
        mem[11] = 32'b000000001100_00000_010_00110_0000011;    // lw  x6, 12(x0)
        mem[12] = 32'b0000000_00001_00110_111_00111_0110011;   // and x7, x6, x1   (HDU stalls 1 cycle, then fwd x6 from MEM/WB)
        mem[13] = 32'b0100000_00010_00001_000_01000_0110011;   // sub x8, x1, x2
        mem[14] = 32'b0000000_00010_00001_000_00000_0110011;   // add x0, x1, x2   (rd=x0, discarded)
        mem[15] = 32'b0000000_00001_00000_000_01001_0110011;   // add x9, x0, x1
    end

endmodule
