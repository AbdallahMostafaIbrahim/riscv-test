# Branch-predictor microbench: count 1+2+...+10 = 55 using a
# backward-branch loop. The loop body is 3 instructions and the
# bne is a classic tight loop branch -- ideal workload for a 2-bit
# predictor. With prediction the only mispredictions are:
#   (1) first iteration: cold BTB miss, predicted NT, actual T
#   (2) last iteration:  BHT trained to T, actual NT (loop exit)
# Both cost 3 bubbles each. All 8 iterations in between are free.
#
# Without prediction every taken branch flushes 3 cycles, so
# 9 taken branches x 3 bubbles = 27 bubbles of penalty.

    addi x1, x0, 0       # x1 = sum
    addi x2, x0, 0       # x2 = i
    addi x3, x0, 10      # x3 = N
loop:
    addi x2, x2, 1       # i++
    add  x1, x1, x2      # sum += i
    bne  x2, x3, loop    # if i != N, back-branch (taken 9x, NT 1x)
    nop                  # drain: lets bne fully resolve + reach WB
    nop                  # before ebreak enters ID, so the halt-freeze
    nop                  # can't interact with branch resolution.
    ebreak
