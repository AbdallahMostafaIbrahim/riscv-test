`timescale 1ns / 1ps

module immediateGen(input [31:0]inst, output [31:0]out);
    reg [11:0]imm;
    always @(*) begin
        if(inst[6] == 1) begin // BEQ (SB-Type)
            imm = { inst[31], inst[7], inst[30:25], inst[11:8] };
        end else begin // LW or SW
            if(inst[5] == 1) begin // SW (S-Type)
                imm = { inst[31:25], inst[11:7] };
            end else begin // LW (I-TYPE)
                imm = inst[31:20];
            end
        end
    end
    
     signExtender #(12, 32) s(imm, out);
endmodule
