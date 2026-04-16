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
> Schematic

### 2.2 Top Level Modules

Those are the modules directly instantiated from `verilog/core/riscv.v`. We have in total
6 core blocks and 2 memories.

| Block           | File                                 | Role                                                    |
| --------------- | ------------------------------------ | ------------------------------------------------------- |
| PC register     | `verilog/primitives/register.v`      | Holds current PC; load blocked by `~halted`             |
| Instruction mem | `verilog/memory/inst_mem.v`          | 4 KiB                                                   |
| Control unit    | `verilog/core/control_unit.v`        | Decodes controld signals from instructions              |
| Register file   | `verilog/core/reg_file.v`            | 32 × 32 bit                                             |
| Immediate gen   | `verilog/core/immediate_gen.v`       | Extracts immediate from all type                        |
| ALU             | `verilog/core/alu.v`                 | 10 ops, 4-bit selector, returns z,c,v,n flags           |
| Branch unit     | `verilog/core/branch_unit.v`         | Takes ALU flags and `funct3` to generate `branch_taken` |
| Data memory     | `verilog/memory/data_mem.v`          | 4 KiB with 4-bit write mask                             |
| Store / Load    | `verilog/memory/{store,load}_unit.v` | Controls the byte/half/word addressability              |

### 2.3 Control-signal summary

All control signals are produced by `control_unit.v` from the
5-bit opcode slice `inst[6:2]`:

| Signal      | Width | Meaning                            |
| ----------- | ----- | ---------------------------------- |
| `alu_sel`   | 4     | ALU op (from `defines.v`)          |
| `alu_src_a` | 2     | `00`=rs1, `01`=PC, `10`=0          |
| `alu_src_b` | 1     | `0`=rs2, `1`=imm                   |
| `branch`    | 1     | if instruction is branch           |
| `jump`      | 1     | if instruction is jalr or jal      |
| `jalr`      | 1     | if instruction is jalr             |
| `mem_read`  | 1     | on loads                           |
| `mem_write` | 1     | on stores                          |
| `wb_src`    | 2     | `00`=ALU, `01`=mem, `10`=PC+4      |
| `reg_write` | 1     | on register write                  |
| `halt`      | 1     | on ECALL / EBREAK / FENCEs / PAUSE |

### 2.4 ALU encoding

The ALU uses 4-bit selector defined in
`verilog/core/defines.v`:

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

Branches force `ALU_SUB`.

---

## 3. Implementation

### 3.1 Instruction fetch

`register` holds the 32-bit PC. A `ripple` adder
computes `PC + 4`. The next-PC mux selects between `PC + 4`,
`PC + imm` (branch / JAL), and `(rs1 + imm) & ~1` (JALR) based on
`branch_taken`, `jump`, and `jalr`. A `~halted` blocks the pc load signal.

### 3.2 Decode

`control_unit.v` is decoder that decodes the intructions and returns all
the control signals listed in the above table.

### 3.3 Execute

`alu_src_a` selects between rs1, PC, 0 (for LUI). `alu_src_b`
selects between rs2 and the immediate. The ALU outputs the result along with
z,c,x,v flags so branch unit can determine if `branch_taken` from
one subtract.

### 3.4 Memory access

`data_mem` is word-addressable internally:

```
reg [31:0] mem [0:1023];
```

but inputs a 4-bit, `write_mask` so each byte inside the word can be written independently like so:

```verilog
if (write_mask[0]) mem[word_addr][ 7: 0] <= wdata[ 7: 0];
if (write_mask[1]) mem[word_addr][15: 8] <= wdata[15: 8];
if (write_mask[2]) mem[word_addr][23:16] <= wdata[23:16];
if (write_mask[3]) mem[word_addr][31:24] <= wdata[31:24];
```

`store_unit` produces the mask and replicates the byte or halfword into `wdata`

`load_unit` extracts the byte or halfword from the read word and does either sign-extension or zero-extension based on `funct3`.

### 3.5 Write back

A 3:1 mux selects the value written back to the register file from
`alu_out`, `load_out`, or `pc + 4` (for JAL/JALR), based on
`wb_src`. Writes are stopped when `halted` or when `reg_write` is low.

---

## 5. Testing

### 5.1 Strategy

Each instruction format has its own assembly program under
`test/asm/` and a matching self-checking testbench under
`test/test_benches/`. The assembly sources are assembled into
`$readmemh` parameters in `test/mem/` (alongside `data.hex`), and
the testbench, by default, expects the chosen program to be loaded as
`inst.hex`.

In Vivado, pick the target `test/mem/<name>.hex` as the
instruction memory, update `$readmemh` in
`verilog/memory/inst_mem.v` line 22 to match, and select the
corresponding `<name>_tb.v` from `test/test_benches/` as the
top simulation module.

### 5.2 Instructions Tested

| Test bench    | Instructions covered                           | Checks |
| ------------- | ---------------------------------------------- | -----: |
| `i-type_tb.v` | `addi slti sltiu xori ori andi slli srli srai` |      9 |
| `r-type_tb.v` | `add sub sll slt sltu xor srl sra or and`      |     10 |
| `s-type_tb.v` | `sb sh sw`                                     |      3 |
| `load_tb.v`   | `lb lh lw lbu lhu`                             |      5 |
| `b-type_tb.v` | `beq bne blt bge bltu bgeu`                    |     12 |
| `u-type_tb.v` | `lui auipc`                                    |      2 |
| `j-type_tb.v` | `jal jalr`                                     |      5 |

Total: **46 independent checks**, all passing.

### 5.3 Simulation waveforms

> ![R-type waveform](screenshots/r.png)
>
> _`r-type_tb.v` — `write_data` steps through the expected results
> of `add sub sll slt sltu xor srl sra or and` (8, 2, 40, 1, 0, 6,
> `0x1fffffff`=536870911, -1, 7, 1) across 14 cycles with 0 errors._

> ![I-type waveform](screenshots/i.png)
>
> _`i-type_tb.v` — `write_data` shows the results of `addi slti
sltiu xori ori andi slli srli srai` (8, 1, 0, 10, 7, 1, 20, 2,
> -4) over 12 cycles, all passing._

> ![S-type waveform](screenshots/s.png)
>
> _`s-type_tb.v` — `wdata` and `write_mask` exercise the byte-lane
> path: `sw` with mask `1111` writes `0x00000008`, `sh` with mask
> `0011` writes `0x0000ffff`, `sb` with mask `0001` writes the low
> byte of `0x08080808`._

> ![Load waveform](screenshots/load.png)
>
> _`load_tb.v` — after the seed stores of `0x87654321` and
> `0xffffff80`, the reads come back as `0x87654321` (lw),
> `0x00000021` (lb), `0x00000087` (lbu), `0xffffff80` (lh),
> `0x0000ff80` (lhu)._

> ![B-type waveform](screenshots/b.png)
>
> _`b-type_tb.v` — `pc_next` tracks branch resolution across all
> six branch types. Taken branches jump the PC (4→8→12→16→24→...);
> `branch_taken` toggles at each comparison._

> ![U-type waveform](screenshots/u.png)
>
> _`u-type_tb.v` — `write_data = 0xabcde000` after `lui`, then
> `0x00001004` after `auipc` (PC + immediate), confirming both
> upper-immediate forms in 3 cycles._

> ![J-type waveform](screenshots/j.png)
>
> _`j-type_tb.v` — `pc_next` shows the non-sequential jumps
> (8, 12, 16, 20, 28, 32, 36) and `c_jalr` pulses for the `jalr`
> instruction, validating both link and target computation._
