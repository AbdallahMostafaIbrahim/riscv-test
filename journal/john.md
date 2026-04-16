# John Saif (900232149)

### Register File

- `verilog/core/reg_file.v`: 32 × 32 bits, `x0` hard-wired to zero,
  synchronous write with async reset.

### Test infrastructure

- Wrote the per-instruction-type assembly programs
  (`tests/i-type.s`, `r-type.s`, `s-type.s`, `load.s`, `b-type.s`,
  `u-type.s`, `j-type.s`).
- Wrote the matching self-checking testbenches in `test/`.
- Wrote `test/dump_tb.v` for one-off tests dumping the register file and memory

### Execute path

- `verilog/core/alu.v`: all 10 RV32I ops. SUB reuses the adder via
  `~b + 1`. Exposes Z,C,N,V flags so the branch unit can
  evaluate from the subtraction.
- `verilog/core/branch_unit.v`: maps the six branch `funct3` codes
  onto the ALU flags.

### Program counter and control transfer

- PC + imm adder and the next-PC mux across `PC + 4`, branch
  target, JAL target, and JALR target (with 2-byte alignment via
  `alu_out & ~1`).
