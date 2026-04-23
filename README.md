# Project 1 RV32I RISC-V Processor (Milestone 3)

## Team

| Name                     | ID        |
| ------------------------ | --------- |
| Abdallah Mostafa Ibrahim | 900232544 |
| John Saif                | 900232149 |

## Milestone 3 Scope

This milestone delivers a **5-stage pipelined** RV32I core (IF - ID -
EX - MEM - WB) backed by a **single single-ported, byte-addressable
memory** that holds both instructions and data. Hazards are handled
with a forwarding unit, a hazard/stall unit, and a MEM-stage flush.

### What Works

- All **37 user-level RV32I instructions** (same coverage as MS2):
  - R-type: `add sub sll slt sltu xor srl sra or and`
  - I-type ALU: `addi slti sltiu xori ori andi slli srli srai`
  - Loads: `lb lh lw lbu lhu`
  - Stores: `sb sh sw`
  - Branches: `beq bne blt bge bltu bgeu`
  - Upper-immediate: `lui auipc`
  - Jumps: `jal jalr`
- All **5 halting opcodes** (`ecall ebreak fence fence.tso pause`)
  freeze the PC once they reach ID and mark the program as done once
  they reach WB.
- **5-stage pipeline**: IF - ID - EX - MEM - WB with four pipeline
  registers (`if_id`, `id_ex`, `ex_mem`, `mem_wb`) built from the
  `register` primitive.
- **Unified single-port memory** (`verilog/memory/memory.v`): 4 KiB,
  1024 x 32-bit words, byte-write mask, shared between IF and MEM.
  The hazard unit stalls IF on every load/store cycle so the two
  consumers never collide at the port.
- **Forwarding** (`verilog/core/forwarding_unit.v`): EX/MEM and
  MEM/WB bypass into EX for 1- and 2-instruction RAW hazards.
- **Stalls** (`verilog/core/hazard_unit.v`): 1-cycle load-use stall
  and 1-cycle structural stall whenever MEM holds the shared memory
  port.
- **3-instruction RAW** handled by writing the register file on the
  **negative clock edge** so WB writes land before ID reads in the
  same cycle.
- **Flush on taken branch / JAL / JALR**: the three wrong-path
  instructions in IF, ID, and EX are bubbled by forcing the
  pipeline-register inputs to zero.
- **Self-checking testbenches** (all passing):
  - `test/test_benches/i-type_tb.v` (9 checks)
  - `test/test_benches/r-type_tb.v` (10 checks)
  - `test/test_benches/s-type_tb.v` (3 checks)
  - `test/test_benches/load_tb.v`   (5 checks)
  - `test/test_benches/b-type_tb.v` (12 checks)
  - `test/test_benches/u-type_tb.v` (2 checks)
  - `test/test_benches/j-type_tb.v` (5 checks)
- **Hazard smoke tests** (runnable with `dump_tb.v`):
  - `test/asm/pipe.s`    - minimal RAW + branch pipeline exercise.
  - `test/asm/forward.s` - full scorecard covering 1-, 2-, and
    3-instruction RAW, load-use stall, single-port structural
    stall, and branch / JAL / JALR flushes.

### What Doesn't Work / What's Deferred

- No bonuses (no RV32IC, no RV32IM, no branch prediction, no
  early-resolve branches, no alt. structural-hazard fix).

## Assumptions

- **Memory size:** 4 KiB, 1024 words of 32 bits, byte-addressable
  via a 4-bit per-byte `write_mask`. Reads return the full 32-bit
  word; `load_unit` does byte / halfword selection and sign /
  zero-extension.
- **Memory layout:** words `0..255` (addresses `0x000..0x3FF`) hold
  the program, words `256..1023` (`0x400..0xFFF`) are data. Test
  programs set `x28 = 0x400` and use it as the data base so loads
  and stores cannot overwrite instructions.
- **Reset:** asynchronous active-high `rst` clears PC and register
  file and zeroes all pipeline registers.
- **Halt:** once a halting opcode reaches ID, `halt_pending` freezes
  PC and IF/ID so no new instructions enter the pipeline while the
  earlier ones drain. `halted` goes high once the halt has reached
  WB; the testbenches wait on this.
- **Branch resolution:** branches, JAL, and JALR all resolve in MEM
  (textbook MIPS-style). A taken redirect flushes three bubbles
  into IF/ID, ID/EX, and EX/MEM.
- **Register file:** negative-edge triggered write so WB in the
  first half of the cycle is visible to ID in the second half.

## How to Test

### Quick path: Icarus Verilog + Makefile

The repo includes a `Makefile` that wraps `iverilog` and the
custom assembler (`tools/asm.py`).

```sh
# Per-instruction-type self-checking tests:
make test-i-type
make test-r-type
make test-s-type
make test-load
make test-b-type
make test-u-type
make test-j-type

# Ad-hoc programs (assembles and dumps reg file + data memory):
make run PROG=pipe        # pipeline smoke test
make run PROG=forward     # hazard / flush scorecard
```

`test-<name>` assembles `test/asm/<name>.s` into
`test/mem/<name>.hex`, copies it to `test/mem/inst.hex` (what
`memory.v` reads via `$readmemh`), and runs the matching testbench
under `test/test_benches/<name>_tb.v`. `make run PROG=<name>` is
the same pipeline but against the generic `dump_tb.v` that prints
every register and the first 8 words of data memory.

### Vivado

In Vivado, pick the target `test/mem/<name>.hex` as instruction
memory (copy it to `inst.hex`, which is what `memory.v` reads on
line 47), add the Verilog under `verilog/` to the project, and
select the corresponding `<name>_tb.v` as the simulation top.

## Directory Layout

Mapped against the deliverable structure in the project description:

```
.
├── README.md               # this file
├── REPORT.pdf              # Milestone 3 Report
├── Makefile                # iverilog build / test driver
├── tools/
│   └── asm.py              # minimal RV32I assembler (.s -> .hex)
├── journal/                # one journal per team member
│   ├── abdallah.md
│   └── john.md
├── verilog/                # RTL
│   ├── core/               # defines.v, alu.v, control_unit.v,
│   │                       # branch_unit.v, immediate_gen.v,
│   │                       # reg_file.v, forwarding_unit.v,
│   │                       # hazard_unit.v, riscv.v (top)
│   ├── memory/             # memory.v (unified, single-port),
│   │                       # load_unit.v, store_unit.v
│   └── primitives/         # flip_flop.v, full_adder.v, mux.v,
│                           # register.v, ripple.v
└── test/
    ├── asm/                # r-type.s, i-type.s, s-type.s, load.s,
    │                       # b-type.s, u-type.s, j-type.s,
    │                       # pipe.s, forward.s
    ├── mem/                # assembled *.hex; inst.hex is what
    │                       # memory.v $readmemh's on reset
    └── test_benches/       # <name>_tb.v per type + dump_tb.v
```
