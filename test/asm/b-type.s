# B-Type Instructions
    addi  x20, x0,  5            # setup
    addi  x21, x0,  3            # setup
    addi  x22, x0, -1            # setup (= 0xFFFFFFFF)

    addi  x1, x0, 1              # x1 = 1
    beq   x20, x20, beq_ok       # 5 == 5, so taken        
    addi  x10, x0, 99            # (skipped)
beq_ok:

    addi  x2, x0, 2              # x2 = 2
    bne   x20, x21, bne_ok       # 5 != 3 , so taken        
    addi  x11, x0, 99            # (skipped)
bne_ok:

    addi  x3, x0, 3              # x3 = 3
    blt   x22, x20, blt_ok       # -1 < 5, so taken       
    addi  x12, x0, 99            # (skipped)
blt_ok:

    addi  x4, x0, 4              # x4 = 4
    bge   x20, x22, bge_ok       # 5 >= -1, so taken        
    addi  x13, x0, 99            # (skipped)
bge_ok:

    addi  x5, x0, 5              # x5 = 5
    bltu  x21, x20, bltu_ok      # 3 < 5  -> taken          
    addi  x14, x0, 99            # (skipped)
bltu_ok:

    addi  x6, x0, 6              # x6 = 6
    bgeu  x22, x20, bgeu_ok      # 0xFFFFFFFF >= 5 
    addi  x15, x0, 99            # (skipped)
bgeu_ok:

    ebreak
