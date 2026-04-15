# Journal — John Saif (900232149)

Activity log for Project 1 (riscv32Project). Format follows the
project description example.

---

April 14, 10:30 AM: Project kickoff with Abdallah. Agreed on
                    directory layout, naming conventions, and
                    single `defines.v` for constants.

April 14, 04:15 PM: Drafted the RV32I assembler (tools/asm.py).
                    Two-pass scheme: first pass records labels
                    and PCs, second pass encodes each
                    instruction. Supports every opcode the core
                    needs plus ABI register names and labels.

April 14, 07:00 PM: Integration testbench (`test/riscv_tb.v`)
                    driving the default.s coverage program. Runs
                    until `ebreak` then prints the full register
                    file + first eight dmem words.

April 15, 10:00 AM: Implemented the ALU (all 10 ops), separated
                    SUB from the generic case by feeding `~b + 1`
                    through the same ripple adder. Status flags
                    (z / c / n / v) exposed for branch_unit.

April 15, 12:30 PM: Branch unit driven by the four ALU flags.
                    Hooked up the PC adder (pc + imm) and the
                    PC mux for jumps / branches / JALR target
                    alignment.

April 15, 02:40 PM: Paired with Abdallah on byte-addressable
                    memory. Wrote the store / load unit tests
                    (s-type.s and load.s) and their
                    testbenches. Caught a bug where SH at addr[1]
                    was writing to the wrong halfword.

April 15, 04:55 PM: Branch testbench initially only checked the
                    "landed" register. Extended the assembly to
                    also poison a per-branch register so the
                    testbench can prove each branch actually
                    skipped its poison.

April 15, 07:45 PM: Read through the coding guidelines document
                    and did a style pass: file headers, include
                    guards on defines.v, no bare numeric constants
                    in case statements.

---

*Add further entries below as MS3 work begins.*
