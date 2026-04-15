# Abdallah Mostafa Ibrahim (900232544)

### Primitives

- All of `rtl/primitives/*`: `flip_flop`, `register`,
  `full_adder`, `ripple`, `mux`, `sign_extender`.

### Control path

- `rtl/core/control_unit.v`: flat opcode-driven decoder covering
  all 37 user-level opcodes plus the 5 halt opcodes.
- `rtl/core/immediate_gen.v` covering all five RV32I formats.
