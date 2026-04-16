# U-Type Instructions - one result per register.
# auipc's value depends on its PC (here it is the second instruction,
# so PC = 4).

    lui   x1, 0xABCDE            # x1 = 0xABCDE000            (lui)
    auipc x2, 0x1                # x2 = PC + 0x00001000 = 0x00001004 (auipc at PC=4)

    ebreak
