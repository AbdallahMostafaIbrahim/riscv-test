# Project 1 — Milestone 3 Report

**5-stage Pipelined RV32I Processor with Unified Single-Port Memory**

| Team member              | ID        |
| ------------------------ | --------- |
| Abdallah Mostafa Ibrahim | 900232544 |
| John Saif                | 900232149 |

---

## 1. Introduction

This report documents Milestone 3 of Project 1: a 5-stage pipelined
implementation of the RV32I base integer instruction set. The core
supports all 37 user-level instructions and treats the five halting
opcodes (`ecall`, `ebreak`, `fence`, `fence.tso`, `pause`) as halt
instructions. Compared to Milestone 2, this milestone adds:

- A 5-stage pipeline (IF - ID - EX - MEM - WB) with four pipeline
  registers.
- A **single, single-ported, byte-addressable memory** shared
  between instruction fetch and data access (the Project
  description's core structural constraint).
- A forwarding unit for EX/MEM and MEM/WB bypassing.
- A hazard unit for load-use stalls and single-port memory
  structural stalls.
- Negative-edge register-file writes so 3-instruction RAW hazards
  resolve without an extra stall.
- Flush logic that squashes the three wrong-path instructions behind
  a taken branch / JAL / JALR.

The core is written in Verilog-2001/2012 and verified with
self-checking testbenches for each instruction type plus two
pipeline-stress programs (`pipe.s`, `forward.s`).

---

## 2. Design

### 2.1 Datapath block diagram

> ![Pipelined datapath](./schematic.png)
>
> Schematic of the 5-stage pipelined datapath with unified single-port
> memory, forwarding, stall, and flush paths.

### 2.2 Top-level modules

These are the modules directly instantiated from
`verilog/core/riscv.v`. Five pipeline stages share one 32-bit
data path, connected through four pipeline registers built from the
`register` primitive.

| Block               | File                                 | Stage | Role                                                                    |
| ------------------- | ------------------------------------ | ----- | ----------------------------------------------------------------------- |
| PC register         | `verilog/primitives/register.v`      | IF    | Holds current PC; `load` gated by halt / stall / flush.                 |
| PC + 4 adder        | `verilog/primitives/ripple.v`        | IF    | Sequential next PC.                                                     |
| Unified memory      | `verilog/memory/memory.v`            | IF/MEM| 4 KiB single-port byte-addressable; holds inst + data.                  |
| IF/ID register      | `verilog/primitives/register.v`      | -     | 96 bits: `{inst, pc+4, pc}`.                                            |
| Control unit        | `verilog/core/control_unit.v`        | ID    | Decodes opcode into all control signals.                                |
| Immediate gen       | `verilog/core/immediate_gen.v`       | ID    | Extracts immediate for all RV32I formats.                               |
| Register file       | `verilog/core/reg_file.v`            | ID/WB | 32 x 32 bits; write on **negedge**, read combinational.                 |
| Hazard unit         | `verilog/core/hazard_unit.v`         | ID    | Generates `stall` (load-use + structural).                              |
| ID/EX register      | `verilog/primitives/register.v`      | -     | 194 bits: reg data, imm, rd, rs1, rs2, funct3, all control.             |
| Forwarding unit     | `verilog/core/forwarding_unit.v`     | EX    | Selects freshest value for rs1/rs2 (id_ex / EX/MEM / MEM/WB).           |
| ALU                 | `verilog/core/alu.v`                 | EX    | 10 ops, 4-bit selector, returns Z/C/V/N flags.                          |
| PC + imm adder      | `verilog/primitives/ripple.v`        | EX    | Computes branch / JAL target.                                           |
| EX/MEM register     | `verilog/primitives/register.v`      | -     | 149 bits: alu_out, rs2, pc+4, pc+imm, rd, funct3, flags, control.       |
| Branch unit         | `verilog/core/branch_unit.v`         | MEM   | Uses ALU flags + funct3 to decide `taken`.                              |
| Store / Load units  | `verilog/memory/{store,load}_unit.v` | MEM   | Byte / halfword selection + mask / extension.                           |
| MEM/WB register     | `verilog/primitives/register.v`      | -     | 105 bits: alu_out, load_out, pc+4, rd, wb_src, reg_write, halt.         |
| Writeback mux       | inside `riscv.v`                     | WB    | 3:1 mux across `alu_out`, `load_out`, `pc+4`.                           |

### 2.3 Control-signal summary

All control signals are produced by `control_unit.v` in the ID stage
and travel down the pipeline inside the pipeline registers. The
full set is unchanged from MS2:

| Signal      | Width | Meaning                            |
| ----------- | ----- | ---------------------------------- |
| `alu_sel`   | 4     | ALU op (from `defines.v`)          |
| `alu_src_a` | 2     | `00`=rs1, `01`=PC, `10`=0          |
| `alu_src_b` | 1     | `0`=rs2, `1`=imm                   |
| `branch`    | 1     | branch instruction                 |
| `jump`      | 1     | `jal` or `jalr`                    |
| `jalr`      | 1     | `jalr` specifically                |
| `mem_read`  | 1     | loads                              |
| `mem_write` | 1     | stores                             |
| `wb_src`    | 2     | `00`=ALU, `01`=mem, `10`=PC+4      |
| `reg_write` | 1     | register writeback                 |
| `halt`      | 1     | ECALL / EBREAK / FENCE* / PAUSE    |

### 2.4 ALU encoding

The ALU uses a 4-bit selector defined in `verilog/core/defines.v`:

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

Branches force `ALU_SUB` so the branch unit can read Z / C / N / V.

---

## 3. Implementation

### 3.1 Pipeline stages

**IF.** The PC is held in a `register` primitive; next-PC is either
`pc + 4` (fall-through), `pc + imm` (taken branch / JAL), or
`(rs1 + imm) & ~1` (JALR). The load enable of the PC and IF/ID
register is `~halt_pending & (flush | ~stall)`: flush always
overrides stall so a branch redirect can clear a stalled wrong-path
instruction.

**ID.** `control_unit` decodes the instruction, `immediate_gen`
extracts the immediate, and the register file is read
combinationally. The `hazard_unit` watches the ID/EX register to
detect load-use and structural hazards (see 3.3). On stall or
flush, the ID/EX register latches zeros so a NOP bubble appears in
EX next cycle.

**EX.** The `forwarding_unit` selects the freshest value for rs1 /
rs2 (see 3.2); the muxed values feed the existing `alu_src_a` /
`alu_src_b` muxes. The ALU computes the result and flags; a
parallel `ripple` adder computes `pc + imm` for branches and JAL.

**MEM.** Branch resolution lives here (textbook MIPS-style):
`branch_unit` turns the latched ALU flags into `taken`, the next-PC
logic picks between `pc_plus_imm` (branch / JAL), `jalr_target`
(`(alu_out) & ~1`), and `pc_plus_4` (from IF). `store_unit` builds
the byte mask and replicated wdata, `load_unit` picks / extends the
read word. Both talk to the unified memory port.

**WB.** A 3:1 mux picks `alu_out`, `load_out`, or `pc+4` based on
`wb_src`. The reg-file write port fires on the negative clock edge
so WB finishes before the next ID read.

### 3.2 Forwarding

`forwarding_unit` produces two 2-bit mux selects:

| Sel    | Source                          | When                                               |
| ------ | ------------------------------- | -------------------------------------------------- |
| `2'b00`| `id_ex_rs{1,2}_data` (no fwd)   | No RAW match with EX/MEM or MEM/WB.                |
| `2'b10`| `ex_mem_alu_out` (EX hazard)    | EX/MEM writes the same reg EX reads (and not x0). |
| `2'b01`| `wb_data_wb` (MEM hazard)       | MEM/WB writes the same reg, no newer EX hazard.   |

This catches 1- and 2-instruction RAW. The 3-instruction RAW case
is handled implicitly by writing the reg file on the negative clock
edge so the write lands before ID's next read.

### 3.3 Hazard / stall logic

`hazard_unit` produces a single `stall` wire covering two cases:

1. **Load-use hazard.** The instruction in EX is a load
   (`id_ex_mem_read`) and its `rd` matches `rs1` or `rs2` of the
   instruction in ID. Forwarding cannot rescue this because the
   load result isn't available until MEM/WB. The fix: stall IF and
   ID for one cycle and bubble ID/EX so next cycle MEM/WB
   forwarding hits.

2. **Single-port memory structural hazard.** The instruction in
   MEM is a load or store, so it's using the unified port. IF
   cannot fetch that cycle; we freeze PC and IF/ID and bubble
   ID/EX. This enforces the "alternating cycle" behaviour the
   Project description calls out — but only on cycles that actually
   need MEM, so straight-line ALU code stays at CPI 1.

When `stall` is asserted:

- PC `load = 0` - PC holds.
- IF/ID `load = 0` - the dependent / pending inst stays in ID.
- ID/EX input is forced to zero - NOP bubble into EX.

Flush always overrides stall so a branch redirect in MEM can
immediately kill the wrong-path instruction even if it happens to
be stalled.

### 3.4 Flush on control hazards

Branches, JAL, and JALR all resolve in MEM. By the time the
redirect signal rises, three wrong-path instructions are in IF, ID,
and EX. We squash them by forcing the `d` input of IF/ID, ID/EX,
and EX/MEM to zero for one cycle. `assign flush = pc_rel_taken_mem
| ex_mem_c_jalr;` — this fires on taken branches, JAL (it's
unconditionally taken), and JALR (separate path because its target
goes through the ALU).

### 3.5 Unified single-port memory

`verilog/memory/memory.v` is 1024 x 32-bit words, byte-write mask,
combinational read. Arbitration is implicit: `mem_port_is_data`
selects MEM's address when MEM is active, else IF's PC. The
read output fans out to both `inst_if` (fetch) and `dmem_rdata_mem`
(load path). Because the hazard unit stalls IF whenever MEM holds
the port, the two consumers never collide.

`$readmemh("inst.hex", mem)` initialises memory at time 0. Our
programs place the data region at word 256 (address `0x400`) so
stores cannot overwrite code. `x28` is conventionally set to
`0x400` at the start of every test program and used as the data
base.

### 3.6 Halt propagation

`halt_pending = halt_id | id_ex_halt | ex_mem_halt | mem_wb_halt`
freezes PC and IF/ID as soon as any halt opcode is decoded, so no
new instructions enter the pipeline while the earlier ones drain.
`halted = mem_wb_halt` is the testbench signal — it goes high once
the halt opcode has itself reached WB, which means every
instruction ahead of it in program order has already committed.

---

## 4. Issues Faced

### 4.1 3-instruction RAW

Classic forwarding from EX/MEM and MEM/WB covers up to
2-instruction RAW. A producer that committed 3 cycles earlier is
already in WB the same cycle the consumer is in ID, which pure
forwarding cannot reach.

**Fix:** move register-file writes to the negative clock edge
(`reg_file.v:35`). WB writes land at mid-cycle; ID reads
combinationally from the file and see the fresh value on the
following posedge. No extra forwarding path was needed.

### 4.2 Branch resolution in MEM - 3 flushed bubbles

Resolving branches in MEM means three wrong-path instructions are
already in the pipeline by the time the redirect is known. We
chose the textbook approach (flush three bubbles) over the MS3
bonus (move resolution to ID) because the flush logic is simpler
and the bonus wasn't in scope.

### 4.3 Single-port memory contention

IF wants the memory port every cycle; MEM only wants it on
loads / stores. We handle contention by stalling IF on exactly the
cycles MEM needs the port (`hazard_unit.mem_stall`). Straight-line
ALU code still runs at CPI 1; load / store dense code degrades
toward the Project description's "every other cycle" baseline.

### 4.4 Stall vs. flush priority

Early on, a branch appearing during a load-use stall never
actually resolved because stall kept freezing IF/ID. Fix: make
`flush` override `stall` in every gating expression
(`pc_load`, `if_id_load`, and the ID/EX input mux), so a taken
branch can always clear the wrong-path inst regardless of
stalling.

---

## 5. Testing

### 5.1 Strategy

Two layers of tests:

1. **Per-instruction self-checking testbenches**
   (`test/test_benches/<name>_tb.v`): assemble the matching
   `test/asm/<name>.s`, run to `ebreak`, then check expected
   register and memory values. Each check prints `PASS` or
   `FAIL`; the summary prints total pass count and errors.
2. **Hazard / pipeline smoke tests**
   (`test/asm/pipe.s`, `test/asm/forward.s`) run under the
   generic `dump_tb.v`, which prints the full register file and
   the first 8 words of the data region so the expected state
   from the program's comments can be verified by eye.

Build is driven by a Makefile wrapping Icarus Verilog and a small
RV32I assembler (`tools/asm.py`). `make test-<name>` assembles,
links, and runs a single testbench; `make run PROG=<name>` does
the same but against `dump_tb.v`.

### 5.2 Instructions Tested

| Test bench    | Instructions covered                           | Checks | Cycles |
| ------------- | ---------------------------------------------- | -----: | -----: |
| `i-type_tb.v` | `addi slti sltiu xori ori andi slli srli srai` |      9 |     17 |
| `r-type_tb.v` | `add sub sll slt sltu xor srl sra or and`      |     10 |     19 |
| `s-type_tb.v` | `sb sh sw`                                     |      3 |     14 |
| `load_tb.v`   | `lb lh lw lbu lhu`                             |      5 |     24 |
| `b-type_tb.v` | `beq bne blt bge bltu bgeu` (taken + not-taken)|     12 |     43 |
| `u-type_tb.v` | `lui auipc`                                    |      2 |      8 |
| `j-type_tb.v` | `jal jalr`                                     |      5 |     19 |

Total: **46 independent checks**, all passing under the pipelined
core and unified memory.

### 5.3 Hazard / pipeline tests

Two additional programs exercise the pipelining machinery end-to-
end. Both halt on `ebreak`; `dump_tb.v` prints the final state.

**`test/asm/pipe.s`** — minimal pipeline smoke test.

- Chains `addi x6,x5,5` - `addi x7,x6,-3` - `add x8,x5,x7` to
  exercise 1- and 2-instruction RAW via forwarding.
- `sw x8, 0(x28)` followed by `lw x9, 0(x28)` exercises the
  single-port structural stall and the load path.
- `beq x5, x5, skip` followed by an instruction that must be
  flushed exercises branch-flush.

Expected final state: `x5=10, x6=15, x7=12, x8=22, x9=22, x11=77,
mem[256]=0x16`, with the flushed `addi x10, x0, 99` leaving `x10=0`.

**`test/asm/forward.s`** — full hazard scorecard.

- Chained 1-inst RAW (`x5..x9` = 10, 15, 20, 25, 30) - EX/MEM
  forwarding.
- 2-inst RAW (`x10=100, x11=101`) - MEM/WB forwarding.
- 3-inst RAW (`x30=55, x31=56`) - negedge reg-file write.
- Store then load of `0xAB` (`mem[256]=0xAB`, `x16=0xAB`) with a
  load-use stall (`x17 = x16 + 1 = 0xAC`).
- Taken `beq` with 3 flushed instructions - `x22/x24/x25`
  stay 0.
- `jal` round-trip with 3 flushed instructions - `x27/x29`
  stay 0 and (critically) the flushed `addi x28, x0, 33` did not
  overwrite the data base, so `x28` is still `0x400`.

### 5.4 Simulation waveforms

> ![R-type waveform](screenshots/r.png)
>
> _`r-type_tb.v` — `write_data` steps through the expected results
> of `add sub sll slt sltu xor srl sra or and`
> (8, 2, 40, 1, 0, 6, `0x1FFFFFFF`, -1, 7, 1) with 0 errors._

> ![I-type waveform](screenshots/i.png)
>
> _`i-type_tb.v` — `write_data` shows the results of
> `addi slti sltiu xori ori andi slli srli srai`
> (8, 1, 0, 10, 7, 1, 20, 2, -4), all passing._

> ![S-type waveform](screenshots/s.png)
>
> _`s-type_tb.v` — `wdata` and `write_mask` exercise the byte-lane
> path: `sw` with mask `1111` writes `0x00000008`; `sh` with mask
> `0011` writes `0x0000ffff`; `sb` with mask `0001` writes the low
> byte of `0x08080808`._

> ![Load waveform](screenshots/load.png)
>
> _`load_tb.v` — after seed stores of `0x87654321` and `0xffffff80`,
> the reads come back as `0x87654321` (lw), `0x00000021` (lb),
> `0x00000087` (lbu), `0xffffff80` (lh), `0x0000ff80` (lhu)._

> ![B-type waveform](screenshots/b.png)
>
> _`b-type_tb.v` — `pc_next` follows branch resolution in MEM for
> every condition; taken branches redirect PC and assert `flush`
> for one cycle; not-taken branches fall through to `pc + 4`._

> ![U-type waveform](screenshots/u.png)
>
> _`u-type_tb.v` — `write_data = 0xabcde000` after `lui`, then
> `0x00001004` after `auipc` (PC + immediate), confirming both
> upper-immediate forms._

> ![J-type waveform](screenshots/j.png)
>
> _`j-type_tb.v` — `pc_next` shows the non-sequential jumps and
> `flush` pulsing for each, with `c_jalr` asserting on the `jalr`
> redirect; link registers hold the correct return addresses._

> ![Pipeline hazard waveform](screenshots/forward.png)
>
> _`forward.s` under `dump_tb` — one capture showing forwarding
> muxes switching on chained RAW, `stall` firing on the `lw` -
> `addi` pair, and `flush` firing on the taken `beq` and `jal`._

---

## 6. Conclusion

The MS3 core meets the project's hard constraint of a single,
single-ported, byte-addressable memory shared between instruction
and data accesses, while still running straight-line ALU code at
CPI 1 thanks to forwarding and selective stalling. All 37
user-level RV32I instructions pass their self-checking
testbenches, the five halt opcodes stop the PC correctly, and the
two hazard-focused programs exercise every hazard class the core
is expected to handle: 1-, 2-, and 3-instruction RAW, load-use,
structural (single-port), taken branch, JAL, and JALR.
