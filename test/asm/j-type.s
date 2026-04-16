# J-Type Instructions - jal and jalr.
# Each jump saves pc+4 in its link register and skips a poison.

    jal   x1, jal_target         # x1 = pc+4 = 0x00000004, jump  (jal)
    addi  x10, x0, 99            # (skipped)
jal_target:
    addi  x2, x0, 2              # x2 = 2 (proves we landed here)

    auipc x20, 0                 # x20 = PC of this auipc (= 12)
    addi  x20, x20, 16           # x20 = 12 + 16 = 28 (addr of jalr_target)
    jalr  x3, 0(x20)             # x3 = pc+4 = 0x00000018, jump  (jalr)
    addi  x10, x0, 99            # (skipped)
jalr_target:
    addi  x4, x0, 4              # x4 = 4 (proves we landed here)

    ebreak
