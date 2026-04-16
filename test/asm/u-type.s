# U-Type Instructions

    lui   x1, 0xABCDE            # x1 = 0xABCDE000            
    auipc x2, 0x1                # x2 = PC + 0x00001000 = 0x00001004

    ebreak
