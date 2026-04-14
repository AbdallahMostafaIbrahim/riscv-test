# Fibonacci: compute the first ten fib numbers into x3.
# x1 = previous term, x2 = current term, x4 = loop counter.

        addi  x1, x0, 0         # fib(0) = 0
        addi  x2, x0, 1         # fib(1) = 1
        addi  x4, x0, 10        # count = 10

loop:
        beq   x4, x0, done      # while (count != 0)
        add   x3, x1, x2        # next = prev + cur
        add   x1, x0, x2        # prev = cur
        add   x2, x0, x3        # cur  = next
        addi  x4, x4, -1        # count--
        jal   x0, loop          # unconditional branch

done:
        sw    x3, 0(x0)         # store final value at dmem[0]
        ebreak
