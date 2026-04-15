# I-Type Instructions - one result per register.
# Setup in x20..x21 ; results in x1..x9 for the testbench to check.

    addi  x20, x0,  5            # setup: x20 = 5
    addi  x21, x0,  -8           # setup: x21 = -8 (for srai)

    addi  x1,  x20, 3            # x1 = 8           (addi: 5 + 3)
    slti  x2,  x20, 10           # x2 = 1           (slti: 5 <s 10)
    sltiu x3,  x21, 1            # x3 = 0           (sltiu: 0xFFFFFFF8 <u 1 is false)
    xori  x4,  x20, 0x0F         # x4 = 0x0A        (xori: 5 ^ 15)
    ori   x5,  x20, 0x02         # x5 = 0x07        (ori:  5 | 2)
    andi  x6,  x20, 0x03         # x6 = 0x01        (andi: 5 & 3)
    slli  x7,  x20, 2            # x7 = 20          (slli: 5 << 2)
    srli  x8,  x20, 1            # x8 = 2           (srli: 5 >> 1)
    srai  x9,  x21, 1            # x9 = -4          (srai: -8 >>a 1, sign-preserved)

    ebreak
