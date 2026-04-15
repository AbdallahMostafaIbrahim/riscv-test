# B-Type Instructions - one branch per instruction.
# Each branch is expected TAKEN. If it fires correctly the
# branch-specific poison addi is skipped, leaving its target
# register (x10..x15) at zero. Testbench checks:
#   x1..x6   = 1..6   (landed value, set before each branch)
#   x10..x15 = 0      (per-branch poison was skipped)

    addi  x20, x0,  5            # setup
    addi  x21, x0,  3            # setup
    addi  x22, x0, -1            # setup (= 0xFFFFFFFF)

    addi  x1, x0, 1              # x1 = 1
    beq   x20, x20, beq_ok       # 5 == 5  -> taken               (beq)
    addi  x10, x0, 99            # poison (must be skipped)
beq_ok:

    addi  x2, x0, 2              # x2 = 2
    bne   x20, x21, bne_ok       # 5 != 3  -> taken               (bne)
    addi  x11, x0, 99
bne_ok:

    addi  x3, x0, 3              # x3 = 3
    blt   x22, x20, blt_ok       # -1 <s 5 -> taken               (blt)
    addi  x12, x0, 99
blt_ok:

    addi  x4, x0, 4              # x4 = 4
    bge   x20, x22, bge_ok       # 5 >=s -1 -> taken              (bge)
    addi  x13, x0, 99
bge_ok:

    addi  x5, x0, 5              # x5 = 5
    bltu  x21, x20, bltu_ok      # 3 <u 5  -> taken               (bltu)
    addi  x14, x0, 99
bltu_ok:

    addi  x6, x0, 6              # x6 = 6
    bgeu  x22, x20, bgeu_ok      # 0xFFFFFFFF >=u 5 -> taken      (bgeu)
    addi  x15, x0, 99
bgeu_ok:

    ebreak
