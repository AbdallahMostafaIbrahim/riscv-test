# Forwarding + stall + flush + unified-memory smoke test.
#
# Full hazard-handling scorecard:
#   - EX/MEM + MEM/WB forwarding for 1- and 2-inst RAW.
#   - Negedge reg-file writes for 3-inst RAW.
#   - hazard_unit: 1-cycle stall for load-use.
#   - hazard_unit: 1-cycle stall for single-port memory conflicts
#     (every load/store stalls IF while MEM uses the port).
#   - MEM-stage flush bubbles IF/ID, ID/EX, EX/MEM on taken branches,
#     JAL, and JALR.
#
# Unified memory layout:
#   words 0..255     (0x000-0x3FF) program
#   words 256..1023  (0x400-0xFFF) data
# x28 holds the data base (0x400) for all loads/stores.
#
# Expected state after halt:
#   x5=10, x6=15, x7=20, x8=25, x9=30         (chained 1-inst RAW)
#   x10=100, x11=101                          (2-inst RAW)
#   x15=0xAB                                  (setup)
#   mem[256]=0xAB, x16=0xAB, x17=0xAC         (store/load/load-use)
#   x20=7, x21=7, x22=0, x23=88               (branch + flush)
#   x24=0, x25=0, x26=0                       (flushed by beq)
#   x27=0, x29=0, x12=42, x1=(after_jal+4)    (flushed by jal)
#   x28=0x400                                 (data base; flushed
#                                              `addi x28,..,33` proves
#                                              the jal flush worked)
#   x30=55, x31=56                            (3-inst RAW via negedge)

    # ---- Data base pointer ----
    addi  x28, x0, 0x400         # x28 = 0x400

    # ---- Chained 1-inst RAW (EX/MEM forwarding) ----
    addi  x5,  x0,  10           # x5 = 10
    addi  x6,  x5,  5            # x6 = 15
    addi  x7,  x6,  5            # x7 = 20
    addi  x8,  x7,  5            # x8 = 25
    addi  x9,  x8,  5            # x9 = 30

    # ---- 2-inst RAW (MEM/WB forwarding) ----
    addi  x10, x0,  100          # x10 = 100
    addi  x1,  x0,  1            # filler
    addi  x11, x10, 1            # x11 = 101

    # ---- 3-inst RAW (handled by negedge reg-file write) ----
    addi  x30, x0,  55           # x30 = 55
    addi  x3,  x0,  1            # filler 1
    addi  x4,  x0,  2            # filler 2
    addi  x31, x30, 1            # x31 = 56

    # ---- Store + load through unified memory ----
    addi  x15, x0,  0xAB         # x15 = 0xAB
    sw    x15, 0(x28)            # mem[256] = 0xAB

    lw    x16, 0(x28)            # x16 = 0xAB
    addi  x17, x16, 1            # x17 = 0xAC (load-use stall)

    # ---- Branch with forwarded operands; flush replaces delay NOPs ----
    addi  x20, x0,  7
    addi  x21, x0,  7
    beq   x20, x21, target       # taken; flush squashes the 3 below
    addi  x22, x0,  99           # MUST NOT execute (flushed)
    addi  x24, x0,  77           # MUST NOT execute (flushed)
    addi  x25, x0,  66           # MUST NOT execute (flushed)
    addi  x26, x0,  55           # never reached

target:
    addi  x23, x0,  88           # x23 = 88

    # ---- JAL round-trip ----
    jal   x1,  after_jal         # flush squashes 3; x1 = return addr
    addi  x27, x0,  44           # MUST NOT execute (flushed)
    addi  x28, x0,  33           # MUST NOT execute (would clobber
                                  # data base; proves flush worked)
    addi  x29, x0,  22           # MUST NOT execute (flushed)

after_jal:
    addi  x12, x0,  42           # x12 = 42

    # ---- Drain and halt ----
    nop
    nop
    nop
    ebreak
