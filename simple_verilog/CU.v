module CU(
        input [4:0]inst,
        output reg branch, reg memRead, reg memToReg, reg [1:0]ALUOP, reg memWrite, reg ALUSrc, reg regWrite
    );
    
    always @(*) begin
        case(inst) 
            5'b01100: begin
                branch = 0;
                memRead = 0;
                memToReg = 0;
                ALUOP = 2'b10;
                memWrite = 0;
                ALUSrc = 0;
                regWrite = 1;
           end
           5'b00000: begin
                branch = 0;
                memRead = 1;
                memToReg = 1;
                ALUOP = 2'b00;
                memWrite = 0;
                ALUSrc = 1;
                regWrite = 1;
            end
            5'b01000: begin
                branch = 0;
                memRead = 0;
                ALUOP = 2'b00;
                memWrite = 1;
                ALUSrc = 1;
                regWrite = 0;
            end
            5'b11000: begin
                branch = 1;
                memRead = 0;
                ALUOP = 2'b01;
                memWrite = 0;
                ALUSrc = 0;
                regWrite = 0;
            end    
        endcase
    end
    
endmodule
