# Forwarding + stall + flush test.
    # Base pointer for data memory
    addi  x28, x0, 0x400         # x28 = 0x400

    # Chained RAW Dependencies (EX/MEM forwarding)
    addi  x5,  x0,  10           # x5 = 10
    addi  x6,  x5,  5            # x6 = 15
    addi  x7,  x6,  5            # x7 = 20
    addi  x8,  x7,  5            # x8 = 25
    addi  x9,  x8,  5            # x9 = 30

    # RAW Dependency (MEM/WB forwarding)
    addi  x10, x0,  100          # x10 = 100
    addi  x1,  x0,  1            # filler
    addi  x11, x10, 1            # x11 = 101

    # RAW Dependency (3 instructions apart to check negedge writing in regfile)
    addi  x30, x0,  55           # x30 = 55
    addi  x3,  x0,  1            # filler 1
    addi  x4,  x0,  2            # filler 2
    addi  x31, x30, 1            # x31 = 56

    addi  x15, x0,  0xAB         # x15 = 0xAB
    sw    x15, 0(x28)            # mem[256] = 0xAB

    # Store Load Dependency
    lw    x16, 0(x28)            # x16 = 0xAB
    addi  x17, x16, 1            # x17 = 0xAC (expected load-use stall)

    # Forward to branch instruction
    addi  x20, x0,  7
    addi  x21, x0,  7
    beq   x20, x21, target       # taken; flush squashes the 3 below
    addi  x22, x0,  99           # MUST NOT execute
    addi  x24, x0,  77           # MUST NOT execute
    addi  x25, x0,  66           # MUST NOT execute
    addi  x26, x0,  55           # MUST NOT execute

target:
    addi  x23, x0,  88           # x23 = 88

    # JAL flush
    jal   x1,  after_jal         # flush squashes 3; x1 = return addr
    addi  x27, x0,  44           # MUST NOT execute 
    addi  x28, x0,  33           # MUST NOT execute
    addi  x29, x0,  22           # MUST NOT execute

after_jal:
    addi  x12, x0,  42           # x12 = 42
    ebreak
