# R-Type Instructions

    addi  x20, x0,  5            # setup: x20 = 5
    addi  x21, x0,  3            # setup: x21 = 3
    addi  x22, x0,  -1           # setup: x22 = -1

    add   x1,  x20, x21          # x1  = 8          
    sub   x2,  x20, x21          # x2  = 2          
    sll   x3,  x20, x21          # x3  = 40         
    slt   x4,  x22, x20          # x4  = 1          
    sltu  x5,  x22, x20          # x5  = 0          
    xor   x6,  x20, x21          # x6  = 6          
    srl   x7,  x22, x21          # x7  = 0x1FFFFFFF 
    sra   x8,  x22, x21          # x8  = -1         
    or    x9,  x20, x21          # x9  = 7          
    and   x10, x20, x21          # x10 = 1          

    ebreak
