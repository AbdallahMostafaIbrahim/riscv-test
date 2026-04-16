# Project 1 RV32I RISC-V Processor (Milestone 2)

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
  - `test/i-type_tb.v` (9 checks)
  - `test/r-type_tb.v` (10 checks)
  - `test/s-type_tb.v` (3 checks)
  - `test/load_tb.v` (5 checks)
  - `test/b-type_tb.v` (12 checks)
  - `test/u-type_tb.v` (2 checks)
  - `test/j-type_tb.v` (5 checks)

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

## How to Test

Tests are written in RISC-V assembly (one file per instruction type)
and self-check via the matching Verilog testbench that inspects the
register file and data memory after `ebreak`.

The `tests/` folder contains `asm/` (test assembly files), `mem/` (corresponding assembled hex files), `test_benches/` (self-checking test benches for each instruction type). In vivado,
change the initial instruction memory by choosing one of the `*.mem` hex files and change in `verilog/memory/inst_mem.v` line 22:

```verilog
        $readmemh("*-type.hex", mem);
```

Then, choose the corresponding test bench as your top module.
If you want to test a different hex file, change it in the `verilog/memory/inst_mem.v` and add
the hex file to the project.

## Directory Layout

Mapped against the deliverable structure in the project description:

```
.
├── README.md               # this file
├── REPORT.pdf              # Milestone 2 Report
├── journal/                # Journals
│   ├── abdallah.md
│   └── john.md
├── verilog/                #   Verilog code
│   ├── core/               #   defines.v, alu.v, control_unit.v,
│   │                       #   branch_unit.v, immediate_gen.v,
│   │                       #   reg_file.v, riscv.v
│   ├── memory/             #   data_mem.v, inst_mem.v, load_unit.v,
│   │                       #   store_unit.v
│   └── primitives/         #   flip_flop.v, full_adder.v, mux.v,
│                           #   register.v, ripple.v
└── test/                   #   Per-instruction tests
    ├── asm/                #   Assembly sources: r-type.s, i-type.s,
    │                       #   s-type.s, b-type.s, u-type.s,
    │                       #   j-type.s, load.s
    ├── mem/                #   what is used for $readmemh and data.hex
    └── test_benches/       #   testbenches: <name>_tb.v and
                            #   dump_tb.v
```
