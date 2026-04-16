# Load Instructions - one load per instruction.
# Seeds dmem[0] = 0x87654321 and dmem[4..5] = 0xFF80, then reads
# each load variant into its own register.

    # seed dmem via stores
    lui   x20, 0x87654           # x20 = 0x87654000
    addi  x20, x20, 0x321        # x20 = 0x87654321
    sw    x20, 0(x0)             # dmem word 0 = 0x87654321
    addi  x21, x0, -128          # x21 = 0xFFFFFF80
    sh    x21, 4(x0)             # dmem halfword at 4 = 0xFF80

    lw    x1, 0(x0)              # x1 = 0x87654321            (lw)
    lb    x2, 0(x0)              # x2 = 0x00000021            (lb : byte 0 = 0x21, sign-ext)
    lbu   x3, 3(x0)              # x3 = 0x00000087            (lbu: byte 3 = 0x87, zero-ext)
    lh    x4, 4(x0)              # x4 = 0xFFFFFF80            (lh : half = 0xFF80, sign-ext)
    lhu   x5, 4(x0)              # x5 = 0x0000FF80            (lhu: half = 0xFF80, zero-ext)

    ebreak
