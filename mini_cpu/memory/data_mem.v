`timescale 1ns / 1ps

module data_mem (
    input         clk,
    input         mem_read,
    input         mem_write,
    input  [31:0] addr,
    input  [31:0] wdata,
    output [31:0] rdata
);

    reg [31:0] mem [0:1023];

    initial begin
        $readmemh("data.hex", mem);
    end

    wire [9:0] word_addr;
    assign word_addr = addr[11:2];

    always @(posedge clk) begin
        if (mem_write)
            mem[word_addr] <= wdata;
    end

    assign rdata = mem_read ? mem[word_addr] : 32'b0;

endmodule
