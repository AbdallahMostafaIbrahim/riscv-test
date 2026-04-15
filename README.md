# Project 1 RV32I RISC-V Processor (Milestone 2)

CSCE 3301 Computer Architecture, Spring 2026.

## Team

| Name                     | ID        |
| ------------------------ | --------- |
| Abdallah Mostafa Ibrahim | 900232544 |
| John Saif                | 900232149 |

## Milestone 2 Scope

This milestone delivers a **single-cycle** RV32I core with **separate
instruction and data memories** and a basic tests that cover
every instruction at least once.

### What Works

- All **37 user-level RV32I instructions**:
  - R-type: `add sub sll slt sltu xor srl sra or and`
  - I-type ALU: `addi slti sltiu xori ori andi slli srli srai`
  - Loads: `lb lh lw lbu lhu`
  - Stores: `sb sh sw`
  - Branches: `beq bne blt bge bltu bgeu`
  - Upper-immediate: `lui auipc`
  - Jumps: `jal jalr`
- All **5 halting opcodes** (`ecall ebreak fence fence.tso pause`)
  correctly freeze the PC and stop further register / memory
  writes.
- **Self-checking testbenches** for each instruction type, all
  passing:
  - `test/i-type_tb.v` — 9 checks
  - `test/r-type_tb.v` — 10 checks
  - `test/s-type_tb.v` — 3 checks (data memory contents)
  - `test/load_tb.v` — 5 checks
  - `test/b-type_tb.v` — 12 checks (6 taken + 6 poison-skip)
  - `test/u-type_tb.v` — 2 checks
  - `test/j-type_tb.v` — 5 checks (link + landing + poison-skip)

### What Doesn't Work / What's Deferred

- No unified single-ported memory, instruction and data memories are
  still separate.

## Assumptions

- **Memory sizes:** 4 KiB instruction memory, 4 KiB data memory,
  both have 1024 words of 32 bits. Both are initialised
  from hex files using `$readmemh` (`mem/inst.hex` and `mem/data.hex`).
- **Byte-addressability:** data memory is byte-addressable by using a
  4-bit per-byte write mask. Reads always return the full 32-bit word
  and the `load_unit` performs byte / halfword selection.
- **Halt behaviour:** the halt opcodes just freeze the PC.
- **Reset:** synchronous active-high reset clears the PC and the
  register file.

## Issues Faced

### 1. Control Unit Module is too large

The initial `control_unit.v` implemented all 37 RV32I instructions plus the 5 halting opcodes in a single enormous always block with a massive `case` statement. This makes the module harder to maintain, so we will probably split it into multiple modules in the next milestone.

## How to Build and Run

Everything is driven by the top-level `Makefile` using Icarus Verilog.

```
make                      # runs integ + isa regression
make integ                # integration testbench on mem/default.hex
make isa                  # per-case ISA table
make test-i-type          # run tests/i-type.s vs test/i-type_tb.v
make test-r-type          # ...
make test-s-type
make test-load
make test-b-type
make test-u-type
make test-j-type
make run PROG=<name>      # ad-hoc: assembles tests/<name>.s, dumps regs
make asm PROG=<name>      # just assemble tests/<name>.s -> mem/<name>.hex
make wave                 # integ run with VCD dump (build/dump.vcd)
make clean
```

Tests are written in RISC-V assembly (one file per instruction type)
and self-check via the matching Verilog testbench that inspects the
register file and data memory after `ebreak`.

## Directory Layout

Mapped against the deliverable structure in the project description:

```
.
├── README.md               # this file (readme.txt)
├── REPORT.md               # MS2 report (PDF report; markdown for now)
├── journal/                # per-member activity logs
│   ├── abdallah.md
│   └── john.md
├── rtl/                    # Verilog/
│   ├── core/               #   defines.v, alu.v, control_unit.v,
│   │                       #   branch_unit.v, immediate_gen.v,
│   │                       #   reg_file.v, riscv.v
│   ├── memory/             #   data_mem.v, inst_mem.v, load_unit.v,
│   │                       #   store_unit.v
│   └── primitives/         #   flip_flop.v, full_adder.v, mux.v,
│                           #   register.v, ripple.v, sign_extender.v
├── test/                   # test/ (Verilog testbenches)
│   ├── i-type_tb.v ... j-type_tb.v
│   ├── isa_tb.v
│   ├── fibonacci_tb.v
│   ├── riscv_tb.v          # integration regression (mem/default.hex)
│   └── dump_tb.v           # ad-hoc register dump
├── tests/                  # RISC-V assembly programs
│   ├── i-type.s ... j-type.s
│   ├── fibonacci.s
│   └── default.s
├── mem/                    # .hex images ($readmemh sources)
├── tools/
│   └── asm.py              # RV32I assembler (Python)
├── project_description.md
├── coding_guidelines.md
└── Makefile
```
