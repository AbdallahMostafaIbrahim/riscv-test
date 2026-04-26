# A simple 10 iteration Loop to test branch prediction

    addi x1, x0, 0       # x1 = sum
    addi x2, x0, 0       # x2 = i
    addi x3, x0, 10      # x3 = N
loop:
    addi x2, x2, 1       # i++
    add  x1, x1, x2      # sum += i
    bne  x2, x3, loop    # if i != N, taken 9 times, not taken 1 time, so we get 2 misses our branch predictor.
    nop                  
    nop                  
    nop                  
    ebreak
