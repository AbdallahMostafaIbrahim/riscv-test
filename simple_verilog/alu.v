module alu #(parameter N = 32)(
        input [N-1:0]A,
        input [N-1:0]B,
        input [3:0]sel,
        output reg [N-1:0]out,
        output zero
    );
    wire [N-1:0]out_add;
    
    always @(*) begin
        case(sel) 
            4'b0000: // and 
                out = A & B;
            4'b0001: // or
                out = A | B;
            4'b0010: // add
                out = out_add;
            4'b0110: // sub
                out = out_add;
        endcase
    end
    
    ripple #(N) test1(A, sel[2] ? ~B : B, sel[2] ? 1 : 0, out_add); // Add
    assign zero = out == 0 ? 1 : 0; 
endmodule
