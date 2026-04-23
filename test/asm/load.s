# Load Instructions (unified single-port memory)
# Data region starts at 0x400 so stores don't overwrite program code.

    addi  x28, x0, 0x400         # x28 = data base = 0x400

    # seed data memory via stores
    lui   x20, 0x87654           # x20 = 0x87654000
    addi  x20, x20, 0x321        # x20 = 0x87654321
    sw    x20, 0(x28)            # mem[256] = 0x87654321
    addi  x21, x0, -128          # x21 = 0xFFFFFF80
    sh    x21, 4(x28)            # mem[257] halfword[0] = 0xFF80

    lw    x1, 0(x28)             # x1 = 0x87654321
    lb    x2, 0(x28)             # x2 = 0x00000021
    lbu   x3, 3(x28)             # x3 = 0x00000087
    lh    x4, 4(x28)             # x4 = 0xFFFFFF80
    lhu   x5, 4(x28)             # x5 = 0x0000FF80

    ebreak
