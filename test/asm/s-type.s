# S-Type Instructions

    addi  x20, x0, 8             # setup: x20 = 0x00000008
    addi  x21, x0, -1            # setup: x21 = 0xFFFFFFFF

    sw    x20, 0(x0)             # dmem[0:4] = 0x00000008       
    sh    x21, 4(x0)             # dmem[4:5] = 0xFFFF        
    sb    x20, 8(x0)             # dmem[8:8] = 0x08             

    ebreak
