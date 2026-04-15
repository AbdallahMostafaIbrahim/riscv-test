# Project 1 — RV32I RISC-V Processor (Milestone 2)

CSCE 3301 Computer Architecture, Spring 2026.

## Team

| Name                     | ID        |
| ------------------------ | --------- |
| Abdallah Mostafa Ibrahim | 900232544 |
| John Saif                | 900232149 |

## Milestone 2 Scope

This milestone delivers a **single-cycle** RV32I core with **separate
instruction and data memories** and a basic test suite that exercises
every instruction at least once. Pipelining, single-ported unified
memory, hazard handling, and FPGA bring-up are deferred to MS3.

No pipelining is present in this milestone — every instruction
completes in one clock cycle.

## Release Notes

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
  correctly freeze the PC and suppress further register / memory
  writes.
- **Self-checking testbenches** for each instruction type, all
  passing:
  - `test/i-type_tb.v` — 9 checks
  - `test/r-type_tb.v` — 10 checks
  - `test/s-type_tb.v` — 3 checks (dmem contents)
  - `test/load_tb.v` — 5 checks
  - `test/b-type_tb.v` — 12 checks (6 taken + 6 poison-skip)
  - `test/u-type_tb.v` — 2 checks
  - `test/j-type_tb.v` — 5 checks (link + landing + poison-skip)
  - Plus the pre-existing `test/isa_tb.v` and
    `test/fibonacci_tb.v`.
- A minimal **RV32I assembler** (`tools/asm.py`) supporting ABI /
  numeric register names, labels, and every implemented opcode.

### What Doesn't Work / What's Deferred

- No pipelining yet.
- No hazard detection or forwarding.
- No unified single-ported memory; instruction and data memories are
  still separate.
- FPGA synthesis has not been attempted on the Nexys A7.

## Assumptions

- **Memory sizes:** 4 KiB instruction memory, 4 KiB data memory,
  both organised as 1024 words of 32 bits. Both are initialised
  from hex files via `$readmemh` (`mem/inst.hex` and `mem/data.hex`).
- **Byte-addressability:** data memory is byte-addressable by using a
  4-bit per-byte write mask; reads always return the full 32-bit word
  and the `load_unit` performs byte / halfword selection and sign- or
  zero-extension.
- **Alignment:** halfword and word accesses are assumed aligned.
  Unaligned accesses are not trapped.
- **Halt behaviour:** the halt opcodes do not jump to a trap handler
  or update any CSR; they merely freeze the PC (sticky behaviour).
- **Reset:** synchronous active-high reset clears the PC and the
  register file. `x0` is hard-wired to zero and ignores writes.
- **Endianness:** little-endian byte ordering in data memory, matching
  the RV32I convention.

## Issues Faced

### 1. Byte-addressable data memory

The spec requires byte-addressable memory but a naive 32-bit-word
array breaks `sb` and `sh`: a byte store would corrupt the other
three bytes of the word.

**Fix:** model `data_mem` as a word-addressable array indexed by
`addr[11:2]`, but drive writes through a 4-bit `write_mask` that
gates each byte lane independently:

```verilog
if (write_mask[0]) mem[word_addr][ 7: 0] <= wdata[ 7: 0];
if (write_mask[1]) mem[word_addr][15: 8] <= wdata[15: 8];
if (write_mask[2]) mem[word_addr][23:16] <= wdata[23:16];
if (write_mask[3]) mem[word_addr][31:24] <= wdata[31:24];
```

The `store_unit` translates `funct3` + `addr_low[1:0]` into the
correct mask (`0001`, `0010`, `0100`, `1000` for `sb`; `0011` /
`1100` for `sh`; `1111` for `sw`) and also replicates the byte /
halfword into the right lane of `wdata` so the lane the mask enables
is already aligned.

The symmetric `load_unit` extracts the right byte or halfword from
the full word returned by `data_mem` and sign- or zero-extends per
`funct3`.

### 2. Branches share the ALU with arithmetic

Branch conditions need signed/unsigned comparisons with carry and
overflow awareness. Rather than duplicate the adder, the control
unit forces `alu_sel = SUB` on every branch so the ALU's `z`, `c`,
`n`, `v` flags drive a small `branch_unit` that maps the six
`funct3` codes to a single `taken` bit.

### 3. Compact ALU selector encoding

The ALU selector was initially 5-bit (`{funct7[5], funct3}`) which
was a nice pass-through but included unused codes. It was compressed
to the 4-bit encoding defined in `rtl/core/defines.v` (`ALU_ADD`,
`ALU_SUB`, ...). The control unit now maps `{inst[30], funct3}` to
this 4-bit selector via explicit case statements.

### 4. Magic-number hygiene

Per the Verilog coding guidelines ("do not use hard-coded numeric
values"), all opcodes, funct3 codes, branch codes, instruction-field
slices and the ALU selector values are defined as `` `define ``
macros in `rtl/core/defines.v` and `` `include `` d wherever needed.
The Makefile adds `-I rtl/core` so the include resolves regardless of
compilation directory.

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

## Plan for MS3

- 5-stage pipeline (IF / ID / EX / MEM / WB).
- Unified single-ported byte-addressable memory, issuing every
  other cycle to resolve the structural hazard (effective CPI ≈ 2).
- Data-hazard detection (RAW) with register-file write-before-read
  in the same cycle.
- Control-hazard handling (branches / jumps).
- Full regression on FPGA (Nexys A7) — synthesize, place and
  route, program, exercise via switches and LEDs.
- Revisit bonuses after the base pipeline is green.
