# femtoRV32 — Milestone 2 Plan

Single-cycle RV32I datapath + Verilog implementation and basic per-instruction tests.

## Scope

- All 37 real RV32I user-level instructions supported.
- 5 halting opcodes (ECALL, EBREAK, PAUSE, FENCE, FENCE.TSO) freeze the PC via a sticky `halted` flag.
- Byte-addressable memory, separate instruction and data ports (MS2 allows split; MS3 unifies).
- Simulator: Vivado XSim and Icarus Verilog (same plain-Verilog testbenches).
- Coding guidelines from `coding_guidelines.md` strictly enforced throughout.

## High-level datapath

```
           +-----+        +---------+
   +-------| PC  |------->| inst_mem|--> instruction
   |       +-----+        +---------+           |
   |          ^                                  |
   |          |  pc_src                          v
   |    +-----+------+                     +-----------+
   |    | pc_mux     |<----branch_taken----| branch_unit|<-- flags
   |    | pc+4       |                     +-----------+
   |    | pc+imm     |<-- pc_branch adder
   |    | alu_out&~1 |<-- JALR target (from ALU)
   |    +------------+
   |
   |   +---------+    +----------------+    +-----+
   +-->|reg_file |--> | alu_src_a / b  |--> | ALU |--+
       | rs1/rs2 |    +----------------+    +-----+  |
       +---------+       ^          ^                |
                         |          |                v
                +--------+-+     +-----+       +-----------+
                | imm_gen |     | pc  |       | data_mem  |
                +---------+     +-----+       | (+store_  |
                                              |  unit on  |
                                              |  write,   |
                                              |  load_    |
                                              |  unit on  |
                                              |  read)    |
                                              +-----------+
                                                    |
                                              +-----+------+
                                              | wb_src mux |
                                              | alu / mem  |
                                              | / pc+4     |
                                              +-----+------+
                                                    |
                                                    v
                                              write back to rd
```

## Control signals (from flat decoder)

| signal       | width | meaning |
|--------------|-------|---------|
| `alu_sel`    | 5     | ALU operation; encoded as `{funct7[5], funct3}` (see table below) |
| `alu_src_a`  | 2     | 00 = rs1, 01 = pc, 10 = 0 (for LUI) |
| `alu_src_b`  | 1     | 0 = rs2, 1 = imm |
| `branch`     | 1     | instruction is a conditional branch |
| `jump`       | 1     | instruction is JAL or JALR |
| `jalr`       | 1     | distinguishes JALR (use ALU output as target) from JAL (use pc+imm) |
| `mem_read`   | 1     | load in progress |
| `mem_write`  | 1     | store in progress |
| `wb_src`     | 2     | 00 = ALU, 01 = mem, 10 = pc+4 |
| `reg_write`  | 1     | write rd |
| `halt`       | 1     | halting opcode (ECALL/EBREAK/PAUSE/FENCE/FENCE.TSO) |

### PC source derivation (in top)

```
take_branch   = branch & branch_taken        // from branch_unit
jal_relative  = jump & ~jalr
jalr_absolute = jump & jalr

pc_next = jalr_absolute ? { alu_out[31:1], 1'b0 }
       : (take_branch | jal_relative) ? pc_plus_imm
       : pc_plus_4
```

## ALU

5-bit `alu_sel` encoding mirrors `{funct7[5], funct3}` so R-type decode is a pass-through:

| sel     | op   |
|---------|------|
| 00000   | ADD  |
| 10000   | SUB  |
| 00001   | SLL  |
| 00010   | SLT  |
| 00011   | SLTU |
| 00100   | XOR  |
| 00101   | SRL  |
| 10101   | SRA  |
| 00110   | OR   |
| 00111   | AND  |

ALU exposes flags **Z, C, V, N**:
- `z` — `out == 0`
- `n` — `out[31]`
- `c` — carry-out of the internal ripple adder
- `v` — signed overflow of add/sub: `(a[31] == b_eff[31]) & (out[31] != a[31])`

For branches the control unit forces `alu_sel = SUB` so flags reflect `rs1 - rs2`.

Shifts, logical ops, SLT, SLTU use Verilog native operators. ADD / SUB use the existing `ripple` primitive so we can extract the carry-out cleanly.

## Branch unit

Combinational, consumes flags + funct3:

| funct3 | branch | condition   |
|--------|--------|-------------|
| 000    | BEQ    | `z`         |
| 001    | BNE    | `~z`        |
| 100    | BLT    | `n ^ v`     |
| 101    | BGE    | `~(n ^ v)`  |
| 110    | BLTU   | `~c`        |
| 111    | BGEU   | `c`         |

Produces `branch_taken`, consumed by pc_src logic.

## Immediate generator

All 5 RV32I formats, output is a 32-bit sign-extended byte-offset / value.

| opcode     | format | immediate assembly |
|------------|--------|--------------------|
| 0010011, 0000011, 1100111 | I | sign-ext `inst[31:20]` |
| 0100011    | S      | sign-ext `{inst[31:25], inst[11:7]}` |
| 1100011    | B      | sign-ext `{inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}` |
| 0110111, 0010111 | U | `{inst[31:12], 12'b0}` (no sign-ext) |
| 1101111    | J      | sign-ext `{inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}` |
| other      | —      | 32'b0 |

`left_shifter.v` is deleted — B/J immediates already encode the ×2 factor.

## Memory

### Instruction memory

- 4 KiB = 1024 × 32-bit words, word-addressed internally via `addr[11:2]`.
- Read-only; loaded from `mem/inst.hex` by `$readmemh`.
- Interface: `input [31:0] addr; output [31:0] data_out`.

### Data memory

- 4 KiB = 1024 × 32-bit words.
- Byte-write-enables: `wstrb[3:0]` selects which byte lanes get written.
- Interface:
  ```
  input  clk
  input  [31:0] addr
  input  [31:0] wdata
  input  [3:0]  wstrb
  output [31:0] rdata
  ```
- Initial contents loaded from `mem/data.hex` by `$readmemh` (blank / sparse OK).
- Internal representation: one 32-bit word array; byte-lane writes gated on `wstrb[i]`.

### Store unit (combinational)

Produces `wdata` and `wstrb` for `data_mem` from `rs2_data`, `addr[1:0]`, `funct3`, and `mem_write`:

| funct3 | op  | wstrb            | wdata |
|--------|-----|------------------|-------|
| 000    | SB  | `4'b0001 << addr_lo` | replicate `rs2[7:0]` into the correct byte lane |
| 001    | SH  | `4'b0011 << {addr[1], 1'b0}` | replicate `rs2[15:0]` into the correct halfword lane |
| 010    | SW  | `4'b1111` | `rs2` |

When `mem_write = 0`, `wstrb = 4'b0000`.

### Load unit (combinational)

Extracts and sign/zero-extends from `word_in`, `addr[1:0]`, `funct3`:

| funct3 | op  | result |
|--------|-----|--------|
| 000    | LB  | byte at `addr_lo`, sign-extended |
| 001    | LH  | halfword at `addr[1]`, sign-extended |
| 010    | LW  | full word |
| 100    | LBU | byte at `addr_lo`, zero-extended |
| 101    | LHU | halfword at `addr[1]`, zero-extended |

Misaligned loads/stores are not trapped — our impl silently uses `addr[31:2]` for the word index.

## Halt handling

`halt_unit.v`: one sticky FF, async active-high reset.

```
halted <= 1'b1  when halt = 1 (combinational decode high)
halted <= halted  otherwise
```

Halt opcodes: `1110011` (SYSTEM → ECALL, EBREAK) and `0001111` (MISC-MEM → FENCE, FENCE.TSO, PAUSE).

In `riscv.v`:
- `pc.load  = ~halted`
- `reg_write_eff = reg_write & ~halted`
- `mem_write_eff = mem_write & ~halted`  (gates through `store_unit` → wstrb=0)
- `mem_read_eff  = mem_read  & ~halted`

Once set, `halted` stays high until reset — the program has ended.

## Register file

Unchanged from cleanup pass: 32 × 32-bit, `posedge clk` synchronous write, combinational read, x0 hard-wired to 0 via write guard on `write_addr != 0`.

## File layout after MS2

```
rtl/
  core/
    riscv.v            (top, rewritten)
    control_unit.v     (flat decoder, rewritten)
    alu.v              (extended with new ops + flags)
    branch_unit.v      (NEW)
    immediate_gen.v    (all 5 formats, rewritten)
    halt_unit.v        (NEW — sticky halted FF)
    reg_file.v         (unchanged)
  memory/
    inst_mem.v         (widened to 4 KiB)
    data_mem.v         (byte-write-enables, rewritten)
    load_unit.v        (NEW)
    store_unit.v       (NEW)
  primitives/
    ripple.v           (unchanged)
    full_adder.v       (unchanged)
    mux.v              (unchanged)
    sign_extender.v    (unchanged)
    register.v         (unchanged)
    flip_flop.v        (unchanged)
  (DELETED: alu_control.v, left_shifter.v)
mem/
  inst.hex             (regenerated — small cover program)
  data.hex             (preloaded data if any)
test/
  riscv_tb.v           (NEW — integration)
  isa_tb.v             (NEW — table-driven per-instruction)
```

## Testbench strategy

Two plain-Verilog testbenches, both run under XSim and Icarus:

1. **`test/riscv_tb.v` — integration.** Loads `mem/inst.hex`, clocks until `dut.halted_u.halted` goes high (with a max-cycle safety cap), then `$display`s expected vs actual register values for a handful of register-file entries.

2. **`test/isa_tb.v` — ISA-table.** Hierarchical-ref writes into `dut.imem.mem[0]` to poke a single instruction (followed by an EBREAK at `mem[1]`), pre-loads register file entries via hierarchical refs, pulses reset+clock, and checks the expected post-state. Walks through a table covering every instruction class at least once.

No per-module testbenches for MS2.

## Milestones inside MS2

1. Rewrite primitives-facing deps (none needed beyond deletions).
2. ALU v2 with flags.
3. Branch unit.
4. Immediate generator v2.
5. Flat control unit.
6. Halt unit.
7. Data memory v2 + store_unit + load_unit.
8. Instruction memory resized.
9. Top `riscv.v` rewrite wiring all of the above.
10. Integration TB + minimal `mem/inst.hex` program.
11. ISA-table TB.

## Deliverable status

- MS2 Verilog: delivered by this plan.
- MS2 block diagram: to be drawn for the report based on the datapath above.
- MS2 report: not in scope for this session; the plan here + commit history forms the seed.
