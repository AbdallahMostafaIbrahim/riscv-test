# MS2 RV32I coverage program.
# Each line exercises one instruction class. Expected final register
# values are documented next to each instruction.

    addi  x1,  x0,  5          # x1  = 5
    addi  x2,  x0,  3          # x2  = 3

    # --- R-type ALU -----------------------------------------------
    add   x3,  x1,  x2         # x3  = 8
    sub   x4,  x1,  x2         # x4  = 2
    and   x5,  x1,  x2         # x5  = 1
    or    x6,  x1,  x2         # x6  = 7
    xor   x7,  x1,  x2         # x7  = 6

    # --- I-type shifts --------------------------------------------
    slli  x8,  x1,  2          # x8  = 20
    srli  x9,  x8,  1          # x9  = 10
    srai  x10, x4,  1          # x10 = 1

    # --- Set-less-than --------------------------------------------
    slt   x11, x2,  x1         # x11 = 1
    sltu  x12, x2,  x1         # x12 = 1

    # --- Upper-immediate ------------------------------------------
    lui   x13, 0xABCDE         # x13 = 0xABCDE000
    auipc x14, 0x1             # x14 = PC + 0x1000

    # --- Word load / store ----------------------------------------
    sw    x3,  0(x0)           # dmem[0] = 8
    lw    x15, 0(x0)           # x15 = 8

    # --- Byte load / store ----------------------------------------
    sb    x6,  5(x0)           # dmem byte 5 = 7
    lb    x16, 5(x0)           # x16 = 7

    # --- Halfword load / store ------------------------------------
    sh    x7,  6(x0)           # dmem halfword at 6 = 6
    lh    x17, 6(x0)           # x17 = 6

    # --- Equality branches ----------------------------------------
    beq   x1,  x1,  after_beq  # taken
    addi  x18, x0,  99         # skipped -> x18 stays 0
after_beq:
    addi  x19, x0,  42         # x19 = 42

    bne   x1,  x2,  after_bne  # taken
    addi  x20, x0,  99         # skipped
after_bne:
    addi  x21, x0,  77         # x21 = 77

    # --- JAL -------------------------------------------------------
    jal   x22, jal_target      # x22 = PC+4 ; jump
    addi  x23, x0,  88         # skipped
jal_target:
    addi  x24, x0,  55         # x24 = 55

    # --- R-type shifts --------------------------------------------
    sll   x25, x1,  x2         # x25 = 40
    srl   x26, x8,  x2         # x26 = 2
    sra   x27, x4,  x2         # x27 = 0

    # --- BLT / BGE / BLTU / BGEU ---------------------------------
    blt   x2,  x1,  blt_ok     # taken
    addi  x28, x0,  99         # skipped -> x28 stays 0
blt_ok:
    nop

    bge   x1,  x2,  bge_ok     # taken
    addi  x29, x0,  99
bge_ok:
    nop

    bltu  x2,  x1,  bltu_ok    # taken
    addi  x30, x0,  99
bltu_ok:
    nop

    bgeu  x1,  x2,  bgeu_ok    # taken
    addi  x5,  x0,  99         # skipped -> x5 stays 1
bgeu_ok:
    nop

    # --- JALR -----------------------------------------------------
    auipc x31, 0               # x31 = this-PC
    jalr  x31, 8(x31)          # x31 = PC+4 of jalr ; jump to ebreak

    ebreak                     # halt
