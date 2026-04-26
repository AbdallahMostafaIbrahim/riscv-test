# Project 1 RV32I RISC-V Processor (Milestone 3)

## Team

| Name                     | ID        |
| ------------------------ | --------- |
| Abdallah Mostafa Ibrahim | 900232544 |
| John Saif                | 900232149 |

## Project Description

This milestone delivers a **5-stage pipelined** RV32I core (IF - ID -
EX - MEM - WB) backed by a **single single-ported, byte-addressable
memory** that holds both instructions and data. Hazards are handled
with a forwarding unit, a hazard/stall unit, and a MEM-stage flush.
On top of the baseline we deliver **two bonuses**: a 2-bit dynamic
branch predictor with a branch target buffer (Bonus 3) and an
alternative solution to the single-port structural hazard (Bonus 5).

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
  freeze the PC once they reach ID and mark the program as done once
  they reach WB.
- **5-stage pipeline**: IF - ID - EX - MEM - WB with four pipeline
  registers (`if_id_reg`, `id_ex_reg`, `ex_mem_reg`, `mem_wb_reg`)
  living under `verilog/core/stages/`, each built on top of the
  `register` primitive.
- **Unified single-port memory** (`verilog/memory/memory.v`): 4 KiB,
  1024 x 32-bit words, byte-write mask, shared between IF and MEM.
- **Forwarding** (`verilog/core/forwarding_unit.v`): EX/MEM and
  MEM/WB bypass into EX for 1- and 2-instruction RAW hazards.
- **Stalls** (`verilog/core/hazard_unit.v`): 1-cycle load-use stall
  and 1-cycle structural stall whenever MEM holds the shared memory
  port.
- **3-instruction RAW** handled by writing the register file on the
  **negative clock edge** so WB writes land before ID reads in the
  same cycle.
- **Flush on misprediction / JAL / JALR**: the three wrong-path
  instructions in IF, ID, and EX are bubbled by forcing the
  pipeline-register inputs to zero. Correctly-predicted branches do
  not flush.
- **Bonus 3 - 2-bit dynamic branch predictor**
  (`verilog/core/branch_predictor.v`): 64-entry BHT with 2-bit
  saturating counters and a 64-entry BTB (valid + 24-bit tag +
  32-bit target), both indexed by `PC[7:2]`. Looked up
  combinationally in IF, updated synchronously in MEM. The next-PC
  selector lives in `verilog/core/pc_control_unit.v`.
- **Bonus 5 - selective single-port stalling**: rather than the
  every-other-cycle issuing scheme described in the project
  requirements (CPI = 2 for every instruction), we keep a 5-stage
  pipeline and stall IF only on the cycles MEM actually holds the
  port. Straight-line ALU code runs at CPI 1; CPI degrades toward 2
  only on load/store-dense regions.
- **Self-checking testbenches** (all passing) :
  - `test/test_benches/i-type_tb.v` 
  - `test/test_benches/r-type_tb.v` 
  - `test/test_benches/s-type_tb.v` 
  - `test/test_benches/load_tb.v`   
  - `test/test_benches/b-type_tb.v` 
  - `test/test_benches/u-type_tb.v` 
  - `test/test_benches/j-type_tb.v` 
  - `test/test_benches/forward_tb.v` 
  - `test/test_benches/loop10_tb.v` 
- **Predictor speedup measurement**: `loop10.s` runs in **47
  cycles** with the predictor and **68 cycles** with the predictor
  forced off (`assign predict_taken = 0;`) - a 21-cycle / ~31%
  reduction on a 10-iteration counting loop.

## Assumptions

- **Memory size:** 4 KiB, 1024 words of 32 bits, byte-addressable
  via a 4-bit per-byte `write_mask`. Reads return the full 32-bit
  word; `load_unit` does byte / halfword selection and sign /
  zero-extension.
- **Memory layout:** words `0..255` (addresses `0x000..0x3FF`) hold
  the program, words `256..1023` (`0x400..0xFFF`) are data. Test
  programs set `x28 = 0x400` and use it as the data base so loads
  and stores cannot overwrite instructions.
- **Reset:** asynchronous active-high `rst` clears PC, register
  file, BHT (initialised to `2'b01` weakly-not-taken), BTB valid
  bits, and all pipeline registers.
- **Halt:** once a halting opcode reaches ID, `halt_pending` freezes
  PC and IF/ID so no new instructions enter the pipeline while the
  earlier ones drain. `halted` goes high once the halt has reached
  WB; the testbenches wait on this.
- **Branch resolution:** branches consult the predictor in IF and
  speculatively fetch from `predict_target` if the BHT MSB is high
  and the BTB tags match. Conditional branches, JAL, and JALR all
  resolve in MEM; mispredictions / JAL / JALR flush three bubbles.
- **Register file:** negative-edge triggered write so WB in the
  first half of the cycle is visible to ID in the second half.

## How to Test

### Vivado

In Vivado, pick the target `test/mem/<name>.hex` as instruction
memory (copy it to `inst.hex`, which is what `memory.v` reads via
`$readmemh` on reset), add the Verilog under `verilog/` to the
project, and select the corresponding `<name>_tb.v` as the
simulation top. The relevant snippet from `verilog/memory/memory.v`
is:

```verilog
reg     [31:0] mem [0:1023];
integer        i;

// Zero the array first so we have predictable content
initial begin
    for (i = 0; i < 1024; i = i + 1)
        mem[i] = 32'b0;
    $readmemh("inst.hex", mem);
end
```

### Icarus Verilog + Makefile

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

# Hazard / pipeline self-checking tests:
make test-forward      # 27 checks: forwarding, load-use, branch / JAL flush
make test-loop10       # 3 checks + cycle count for branch-predictor speedup

# Run everything:
make test-all

# Ad-hoc programs (assembles and dumps reg file + data memory):
make run PROG=fibonacci
```

`test-<name>` assembles `test/asm/<name>.s` into
`test/mem/<name>.hex`, copies it to `test/mem/inst.hex` (what
`memory.v` reads via `$readmemh`), and runs the matching testbench
under `test/test_benches/<name>_tb.v`. `make run PROG=<name>` is
the same pipeline but against the generic `dump_tb.v` that prints
every register and the first 8 words of data memory. `make
test-all` discovers every `<name>.s` that has a matching
`<name>_tb.v` and reports pass / fail per test.

## Directory Layout

Mapped against the deliverable structure in the project description:

```
.
├── README.md               # this file
├── REPORT.md               # Milestone 3 report (with bonuses)
├── Makefile                # iverilog build / test driver
├── schematic.png           # pipelined datapath diagram
├── journal/                # one journal per team member
│   ├── abdallah.md
│   └── john.md
├── verilog/                # RTL
│   ├── core/               # defines.v, alu.v, control_unit.v,
│   │   │                   # branch_unit.v, immediate_gen.v,
│   │   │                   # reg_file.v, forwarding_unit.v,
│   │   │                   # hazard_unit.v, branch_predictor.v,
│   │   │                   # pc_control_unit.v, riscv.v (top)
│   │   └── stages/         # if_id_reg.v, id_ex_reg.v,
│   │                       # ex_mem_reg.v, mem_wb_reg.v
│   ├── memory/             # memory.v (unified, single-port),
│   │                       # load_unit.v, store_unit.v
│   └── primitives/         # flip_flop.v, full_adder.v, mux.v,
│                           # register.v, ripple.v
└── test/
    ├── asm/                # r-type.s, i-type.s, s-type.s, load.s,
    │                       # b-type.s, u-type.s, j-type.s,
    │                       # forward.s, loop10.s, fibonacci.s
    ├── mem/                # assembled *.hex; inst.hex is what
    │                       # memory.v $readmemh's on reset
    └── test_benches/       # <name>_tb.v per type plus forward_tb.v,
                            # loop10_tb.v, and dump_tb.v
```
