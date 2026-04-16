# Abdallah Mostafa Ibrahim (900232544)

### Byte-addressable data memory

- Designed the per-byte `write_mask` interface between
  `store_unit`, `data_mem`, and `load_unit`.
- Implemented `verilog/memory/`.

### Primitives

- All of `verilog/primitives/*`: `flip_flop`, `register`,
  `full_adder`, `ripple`, `mux`.

### Control path

- `verilog/core/control_unit.v`: flat opcode-driven decoder covering
  all 37 user-level opcodes plus the 5 halt opcodes.
- `verilog/core/immediate_gen.v` covering all five RV32I formats.
