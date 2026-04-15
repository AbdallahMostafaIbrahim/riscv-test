# R-Type Instructions - one result per register.
# Setup in x20..x22 ; results in x1..x10 for the testbench to check.

    addi  x20, x0,  5            # setup: x20 = 5
    addi  x21, x0,  3            # setup: x21 = 3
    addi  x22, x0,  -1           # setup: x22 = -1 (for signed / sra tests)

    add   x1,  x20, x21          # x1  = 8          (add:  5 + 3)
    sub   x2,  x20, x21          # x2  = 2          (sub:  5 - 3)
    sll   x3,  x20, x21          # x3  = 40         (sll:  5 << 3)
    slt   x4,  x22, x20          # x4  = 1          (slt:  -1 <s 5)
    sltu  x5,  x22, x20          # x5  = 0          (sltu: 0xFFFFFFFF <u 5 is false)
    xor   x6,  x20, x21          # x6  = 6          (xor:  5 ^ 3)
    srl   x7,  x22, x21          # x7  = 0x1FFFFFFF (srl:  0xFFFFFFFF >> 3, logical)
    sra   x8,  x22, x21          # x8  = -1         (sra:  -1 >>a 3, sign-preserved)
    or    x9,  x20, x21          # x9  = 7          (or:   5 | 3)
    and   x10, x20, x21          # x10 = 1          (and:  5 & 3)

    ebreak
