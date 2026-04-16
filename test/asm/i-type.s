# I-Type Instructions

    addi  x20, x0,  5            # setup: x20 = 5
    addi  x21, x0,  -8           # setup: x21 = -8 (for srai)

    addi  x1,  x20, 3            # x1 = 8        
    slti  x2,  x20, 10           # x2 = 1        
    sltiu x3,  x21, 1            # x3 = 0        
    xori  x4,  x20, 0x0F         # x4 = 0x0A     
    ori   x5,  x20, 0x02         # x5 = 0x07     
    andi  x6,  x20, 0x03         # x6 = 0x01     
    slli  x7,  x20, 2            # x7 = 20       
    srli  x8,  x20, 1            # x8 = 2        
    srai  x9,  x21, 1            # x9 = -4       

    ebreak
