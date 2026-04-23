# Pipelined RV32I smoke test (unified single-port memory).
#
# With full hazard handling (forwarding, negedge reg-file, stall,
# flush) and a unified single-port memory, this program runs with
# no hand-placed NOPs beyond the drain before ebreak.
#
# Data region starts at 0x400 (word 256). x28 holds the data base.
#
# Expected state after halt:
#   x5  = 10    (addi)
#   x6  = 15    (x5 + 5, RAW)
#   x7  = 12    (x6 - 3, RAW)
#   x8  = 22    (x5 + x7, RAW; uses R-type add)
#   x9  = 22    (lw round trip from mem[256])
#   x10 = 0     (skipped by taken branch; flushed)
#   x11 = 77    (branch landing pad)
#   mem[256] = 0x00000016 (= 22)

    addi  x28, x0,  0x400        # x28 = data base = 0x400

    addi  x5,  x0,  10           # x5 = 10
    addi  x6,  x5,  5            # x6 = 15
    addi  x7,  x6,  -3           # x7 = 12
    add   x8,  x5,  x7           # x8 = 22

    sw    x8,  0(x28)            # mem[256] = 22
    lw    x9,  0(x28)            # x9 = 22

    beq   x5,  x5, skip          # taken (x5 == x5)
    addi  x10, x0, 99            # MUST NOT execute (flushed)

skip:
    addi  x11, x0, 77            # x11 = 77

    nop
    nop
    nop
    ebreak
