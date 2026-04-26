# Compute the 20th Fibonacci number using a loop.
# fib(0)=0, fib(1)=1, fib(20)=6765 (0x1A6D). We get the result in x1.

    addi x1, x0, 0       # a = fib(0)
    addi x2, x0, 1       # b = fib(1)
    addi x3, x0, 20      # n = no. of iterations
loop:
    add  x4, x1, x2      # t = a + b
    add  x1, x0, x2      # a = b
    add  x2, x0, x4      # b = t
    addi x3, x3, -1      # n--
    bne  x3, x0, loop    # while n != 0 (taken 19x, NT 1x)
    ebreak
