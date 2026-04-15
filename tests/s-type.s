# S-Type Instructions - one store per instruction.
# Stores write to dmem; testbench checks dmem contents.

    addi  x20, x0, 8             # setup: x20 = 0x00000008
    addi  x21, x0, -1            # setup: x21 = 0xFFFFFFFF

    sw    x20, 0(x0)             # dmem[0] = 0x00000008       (sw: full word)
    sh    x21, 4(x0)             # dmem[4..5] = 0xFFFF        (sh: halfword, low half of word 1)
    sb    x20, 8(x0)             # dmem[8] = 0x08             (sb: byte, low byte of word 2)

    ebreak
