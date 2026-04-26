# S-Type Instructions
# Data region starts at 0x400 so stores don't overwrite program code.

    addi  x28, x0, 0x400         # x28 = data base = 0x400
    addi  x20, x0, 8             # setup: x20 = 0x00000008
    addi  x21, x0, -1            # setup: x21 = 0xFFFFFFFF

    sw    x20, 0(x28)            # mem[256] = 0x00000008
    sh    x21, 4(x28)            # mem[257] = 0x0000FFFF
    sb    x20, 8(x28)            # mem[258] = 0x00000008

    ebreak
