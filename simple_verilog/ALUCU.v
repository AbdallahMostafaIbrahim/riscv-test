module ALUCU(
        input [2:0]inst1, 
        input inst2, 
        input [1:0]ALUOP,
        output reg [3:0]ALUSEL
    );
    
    always @(*) begin
        if (ALUOP == 2'b00)
            ALUSEL = 4'b0010;
        else if (ALUOP == 2'b01)
            ALUSEL = 4'b0110;
        else if (ALUOP == 2'b10) begin
            if (inst1 == 3'b000) begin
                if (inst2 == 1'b1)
                    ALUSEL = 4'b0110;
                else
                    ALUSEL = 4'b0010;
            end else if (inst1 == 3'b111)
                ALUSEL = 4'b0000;
            else if (inst1 == 3'b110)
                ALUSEL = 4'b0001;
        end
    end
endmodule
