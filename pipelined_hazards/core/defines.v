`ifndef PIPELINED_CPU_DEFINES_V
`define PIPELINED_CPU_DEFINES_V

`define     IR_rs1          19:15
`define     IR_rs2          24:20
`define     IR_rd           11:7
`define     IR_opcode       6:2
`define     IR_funct3       14:12
`define     IR_funct7       31:25

`define     OPCODE_Arith_R  5'b01_100
`define     OPCODE_Load     5'b00_000
`define     OPCODE_Store    5'b01_000
`define     OPCODE_Branch   5'b11_000

`define     F3_ADD_SUB      3'b000
`define     F3_OR           3'b110
`define     F3_AND          3'b111

`define     ALU_ADD         2'b00
`define     ALU_SUB         2'b01
`define     ALU_AND         2'b10
`define     ALU_OR          2'b11

`define     ALUOP_MEM       2'b00
`define     ALUOP_BEQ       2'b01
`define     ALUOP_R         2'b10

`endif
