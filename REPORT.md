# Project 1 — Milestone 2 Report

**Single-cycle RV32I Processor**

| Team member              | ID        |
| ------------------------ | --------- |
| Abdallah Mostafa Ibrahim | 900232544 |
| John Saif                | 900232149 |

---

## 1. Introduction

This report documents Milestone 2 of Project 1: a single-cycle
implementation of the RV32I base integer instruction set. The core
supports all 37 user-level instructions and treats the five halting
opcodes (`ecall`, `ebreak`, `fence`, `fence.tso`, `pause`) as halting instructions.

This processor is written in verilog and verified using self-checking test benches
for each instruction type.

---

## 2. Design

### 2.1 Datapath block diagram

> ![Single-cycle datapath](./schematic.png)
>
> _Placeholder — schematic designed separately; drop the image
> into `screenshots/datapath.png` and update the caption if needed._

### 2.2 Top-level organisation

The core is instantiated from `rtl/core/riscv.v` and is built from
six functional blocks plus two memories:

| Block           | File                             | Role                                             |
| --------------- | -------------------------------- | ------------------------------------------------ |
| PC register     | `rtl/primitives/register.v`      | Holds current PC; load gated by `halted`         |
| Instruction mem | `rtl/memory/inst_mem.v`          | 4 KiB, combinational read                        |
| Control unit    | `rtl/core/control_unit.v`        | Flat opcode-driven decoder                       |
| Register file   | `rtl/core/reg_file.v`            | 32 × 32 bits, `x0` hard-wired to zero            |
| Immediate gen   | `rtl/core/immediate_gen.v`       | I/S/B/U/J formats                                |
| ALU             | `rtl/core/alu.v`                 | 10 ops, 4-bit selector, Z/C/N/V flags            |
| Branch unit     | `rtl/core/branch_unit.v`         | Consumes ALU flags, maps `funct3` -> `taken`     |
| Data memory     | `rtl/memory/data_mem.v`          | 4 KiB with 4-bit byte-lane write mask            |
| Store / Load    | `rtl/memory/{store,load}_unit.v` | Byte / half formatting and sign / zero extension |

### 2.3 Control-signal summary

All control signals are produced by `control_unit.v` from the
5-bit opcode slice `inst[6:2]`:

| Signal      | Width | Meaning                                            |
| ----------- | ----- | -------------------------------------------------- |
| `alu_sel`   | 4     | ALU op (see `defines.v`, `ALU_ADD` ... `ALU_SLTU`) |
| `alu_src_a` | 2     | `00`=rs1, `01`=PC, `10`=0                          |
| `alu_src_b` | 1     | `0`=rs2, `1`=imm                                   |
| `branch`    | 1     | Asserted on B-type; gates `branch_unit`            |
| `jump`      | 1     | Asserted on JAL / JALR                             |
| `jalr`      | 1     | Selects `rs1+imm` target over `PC+imm`             |
| `mem_read`  | 1     | Asserted on loads                                  |
| `mem_write` | 1     | Asserted on stores                                 |
| `wb_src`    | 2     | `00`=ALU, `01`=mem, `10`=PC+4                      |
| `reg_write` | 1     | Gates the register-file write                      |
| `halt`      | 1     | Asserted on ECALL / EBREAK / FENCE\* / PAUSE       |

### 2.4 ALU encoding

The ALU uses a compact 4-bit selector defined in
`rtl/core/defines.v`:

| `alu_sel` | Op   |
| --------- | ---- |
| `0000`    | ADD  |
| `0001`    | SUB  |
| `0011`    | PASS |
| `0100`    | OR   |
| `0101`    | AND  |
| `0111`    | XOR  |
| `1000`    | SRL  |
| `1001`    | SLL  |
| `1010`    | SRA  |
| `1101`    | SLT  |
| `1111`    | SLTU |

Branches force `ALU_SUB` so the resulting Z/C/N/V flags feed
`branch_unit` and avoid a duplicate comparator.

---

## 3. Implementation

### 3.1 Instruction fetch

`register` holds the 32-bit PC. A parallel `ripple` adder
computes `PC + 4`. The next-PC mux selects between `PC + 4`,
`PC + imm` (branch / JAL), and `(rs1 + imm) & ~1` (JALR) based on
`branch_taken`, `jump`, and `jalr`. A `halted` flag gates the PC
load so halting opcodes freeze fetch.

### 3.2 Decode

`control_unit.v` is a flat combinational decoder. Every output is
driven on every path (safe defaults at the top of the `always` block)
so no latches are inferred. R-type and I-ALU opcodes use a nested
case on `{inst[30], funct3}` to pick the ALU operation.

### 3.3 Execute

`alu_src_a` selects between rs1 / PC / 0 (for LUI). `alu_src_b`
selects between rs2 and the immediate. The ALU exposes four status
flags so the branch unit can derive every conditional branch from
one subtract.

### 3.4 Memory access

`data_mem` is word-addressable internally but exposes a 4-bit
`write_mask` so each byte lane can be written independently.

```verilog
if (write_mask[0]) mem[word_addr][ 7: 0] <= wdata[ 7: 0];
if (write_mask[1]) mem[word_addr][15: 8] <= wdata[15: 8];
if (write_mask[2]) mem[word_addr][23:16] <= wdata[23:16];
if (write_mask[3]) mem[word_addr][31:24] <= wdata[31:24];
```

`store_unit` produces the mask and replicates the byte or halfword
into the correct lane of `wdata`; `load_unit` extracts the byte or
halfword from the read word and sign- or zero-extends per `funct3`.

### 3.5 Write-back

A 3:1 mux selects the value written back to the register file from
`alu_out`, `load_out`, or `pc + 4` (for JAL/JALR), driven by
`wb_src`. Writes are suppressed when `halted`, for the `x0`
destination, or when `reg_write` is low.

---

## 4. Issues and Solutions

### 4.1 Byte-addressable data memory

_Problem._ RV32I specifies byte granularity but a simple 32-bit
word array would corrupt neighbouring bytes on `sb` / `sh`.

_Solution._ `data_mem` still stores words but exposes a 4-bit
`write_mask` that individually enables each byte lane. The
`store_unit` derives the mask from `funct3` + `addr_low[1:0]`:
`sb` uses a one-hot mask, `sh` uses `0011`/`1100` based on
`addr[1]`, and `sw` uses `1111`. `wdata` is pre-aligned so the
enabled lane already contains the right bits.

### 4.2 Shared adder for branches

_Problem._ Conditional branches need signed and unsigned
comparisons, which normally require a dedicated comparator.

_Solution._ Force `alu_sel = SUB` on every branch and let
`branch_unit` map the six branch `funct3` codes onto the Z / C /
N / V flags. No extra comparator.

### 4.3 Hard-coded numeric values

_Problem._ The coding guidelines disallow magic numbers; an early
draft was full of literals like `7'b0110011`.

_Solution._ All opcodes, funct3 codes, branch codes, ALU codes,
instruction-field slices, etc. live in `rtl/core/defines.v` and are
`` `include `` d by every consumer. Opcode comparisons use the
5-bit slice `inst[6:2]` since the low two bits are `2'b11` for every
RV32I instruction.

### 4.4 Halting opcodes must stay halted

_Problem._ ECALL / EBREAK / FENCE\*/ PAUSE must end execution, but
the combinational `halt` signal only persists while the halt
instruction is being decoded.

_Solution._ Because `pc_load = ~halted`, once `halt` is high the
PC stops advancing, so the same halt instruction is re-fetched on
every subsequent cycle — the decode is self-sustaining without a
sticky flag.

---

## 5. Testing

### 5.1 Strategy

Each instruction format has its own assembly program under
`tests/` and a matching self-checking testbench under `test/`.
Each testbench:

1. Asserts reset, then de-asserts.
2. Runs the clock until `dut.halted` is high (or a timeout).
3. Inspects `dut.rf.regs[...]` and `dut.dmem.mem[...]` against
   expected values using `check_reg` / `check_word` tasks.
4. Prints a `PASS` / `FAIL` per check and a summary.

All seven per-type tests plus the pre-existing `isa_tb` and
`fibonacci_tb` pass after the `make clean && make test-*`
regression.

### 5.2 Instruction coverage

| Test bench       | Instructions covered                           | Checks |
| ---------------- | ---------------------------------------------- | -----: |
| `i-type_tb.v`    | `addi slti sltiu xori ori andi slli srli srai` |      9 |
| `r-type_tb.v`    | `add sub sll slt sltu xor srl sra or and`      |     10 |
| `s-type_tb.v`    | `sb sh sw`                                     |      3 |
| `load_tb.v`      | `lb lh lw lbu lhu`                             |      5 |
| `b-type_tb.v`    | `beq bne blt bge bltu bgeu`                    |     12 |
| `u-type_tb.v`    | `lui auipc`                                    |      2 |
| `j-type_tb.v`    | `jal jalr`                                     |      5 |
| `isa_tb.v`       | Corner cases (neg imm, sign extension, etc.)   |      9 |
| `fibonacci_tb.v` | End-to-end loop program                        |      5 |

Total: **60 independent checks**, all passing.

### 5.3 Simulation waveforms

> ![Default coverage run](screenshots/wave_default.png)
>
> _Placeholder — `make wave` produces `build/dump.vcd`; open in
> GTKWave and screenshot the signals of interest._

> ![Byte store / load (SB + LB)](screenshots/wave_sb_lb.png)
>
> _Placeholder — focus on `write_mask`, `wdata`, and `load_out`
> for one byte store followed by a byte load._

> ![Branch taken path](screenshots/wave_branch.png)
>
> _Placeholder — show `branch`, `taken`, `pc_out`, `pc_plus_imm`
> across a `beq` that is taken._

### 5.4 Sample testbench output

```
$ make test-i-type
HALT reached at cycle 12 (PC = 0000002c)
PASS addi        : x1 = 00000008
PASS slti        : x2 = 00000001
PASS sltiu       : x3 = 00000000
PASS xori        : x4 = 0000000a
PASS ori         : x5 = 00000007
PASS andi        : x6 = 00000001
PASS slli        : x7 = 00000014
PASS srli        : x8 = 00000002
PASS srai        : x9 = fffffffc
==== i-type_tb: ALL TESTS PASSED (12 cycles) ====
```

---

## 6. Future Work (MS3)

- **5-stage pipeline** (IF / ID / EX / MEM / WB) with pipeline
  registers.
- **Single single-ported memory** shared by IF and MEM stages,
  with an issue-every-other-cycle scheduler to resolve the
  structural hazard.
- **Hazard handling**: RAW forwarding from EX/MEM and MEM/WB
  back to EX; load-use stall; flush on mispredicted branches.
- **FPGA bring-up** on the Nexys A7 trainer kit, including
  switches / LEDs for observability during demo.
- **Thorough testing** on real hardware covering all 42
  instructions (37 + 5 halts) and every hazard path.
- Bonus exploration: 2-bit dynamic branch prediction and/or
  moving branch resolution to the ID stage.

---

## 7. Appendix

### 7.1 Build / run recipe

```
make                  # integ + isa (MS2 regression target)
make test-i-type      # individual per-type testbench
make test-r-type
make test-s-type
make test-load
make test-b-type
make test-u-type
make test-j-type
make isa              # corner-case table
make run PROG=<name>  # ad-hoc: dump all registers + first 8 dmem words
make wave             # generate build/dump.vcd
make clean
```

### 7.2 File-to-module map

See the table in `README.md` (`## Directory Layout`) — every
Verilog file is named after its module per the coding guideline.

### 7.3 Assembler

`tools/asm.py` is a minimal two-pass RV32I assembler covering
exactly the opcodes the core implements. Invoked by the Makefile
to generate `mem/<name>.hex` from `tests/<name>.s`.
