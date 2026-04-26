# John Saif (900232149)

## MS2
### Register File
- `verilog/core/reg_file.v`: 32 × 32 bits, `x0` hard-wired to zero, synchronous write with async reset.

### Test Infrastructure
- Wrote the per-instruction-type assembly programs (`tests/i-type.s`, `r-type.s`, `s-type.s`, `load.s`, `b-type.s`, `u-type.s`, `j-type.s`).
- Wrote the matching self-checking testbenches in `test/`.
- Wrote `test/dump_tb.v` for one-off tests dumping the register file and memory.

### Execute Path
- `verilog/core/alu.v`: all 10 RV32I ops. SUB reuses the adder via `~b + 1`. Exposes Z, C, N, V flags so the branch unit can evaluate from the subtraction.
- `verilog/core/branch_unit.v`: maps the six branch `funct3` codes onto the ALU flags.

### Program Counter and Control Transfer
- PC + imm adder and the next-PC mux across `PC + 4`, branch target, JAL target, and JALR target (with 2-byte alignment via `alu_out & ~1`).

## MS3

### Alternative Single-Port Memory Solution
- Rather than the lecture's proposed solution which forces CPI = 2 throughout, we keep the full 5-stage pipeline and stall IF only on the cycles when MEM actually holds the memory port.
- Straight-line ALU code runs at CPI = 1; performance only degrades toward CPI = 2 on load/store-dense regions — not globally.

### Forwarding Unit
- Implemented the forwarding unit to handle 1- and 2-instruction RAW hazards by bypassing fresher values from later pipeline stages back into EX.


### Halt Propagation Mechanism
- Implemented the halting propagation mechanism to cleanly stop the pipeline, ensuring a halt signal issued in one stage travels correctly through the pipeline without corrupting in-flight instructions.

## MS2 + MS3
### RISC-V Core (`riscv.v`)
- Worked jointly with Abdallah on the top-level core file, integrating all pipeline stages, control signals, and pipeline registers into a unified, functioning processor.
