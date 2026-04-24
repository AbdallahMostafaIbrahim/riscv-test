`timescale 1ns / 1ps

module inst_mem (
    input  [31:0] addr,
    output [31:0] data_out
);

    reg [31:0] mem [0:1023];

    initial begin
        $readmemh("inst.hex", mem);
    end

    assign data_out = mem[addr[11:2]];

endmodule
