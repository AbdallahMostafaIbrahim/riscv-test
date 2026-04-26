# Abdallah Mostafa Ibrahim (900232544)

## MS2

### Byte-Addressable Data Memory
- Designed the per-byte `write_mask` interface between `store_unit`, `data_mem`, and `load_unit`.
- Implemented `verilog/memory/`.

### Primitives
- All of `verilog/primitives/*`: `flip_flop`, `register`, `full_adder`, `ripple`, `mux`.

### Control Path
- `verilog/core/control_unit.v`: flat opcode-driven decoder covering all 37 user-level opcodes plus the 5 halt opcodes.
- `verilog/core/immediate_gen.v` covering all five RV32I formats.

## MS3

### 2-Bit Dynamic Branch Prediction
- Instead of always assuming "not taken," the processor now learns from history using two 64-entry lookup tables.
- **BHT (Branch History Table):** Each entry holds a 2-bit saturating counter tracking recent branch behavior. It takes two consecutive mispredictions to change state, making it more stable than a 1-bit predictor.
- **BTB (Branch Target Buffer):** Stores the last known target address for each branch, so the processor knows where to fetch from when predicting "taken."
- Both tables are checked combinationally in the Fetch stage and updated in MEM once the true outcome is known. A correct prediction means no flush keeping the pipeline running smoothly and avoiding wasted cycles.

### Hazard Detection Unit & Flush Control
- Implemented the hazard detection unit, which identifies load-use early and triggers the appropriate stalls before they cause incorrect behavior.
- Implemented flush control for handling control hazards, ensuring that wrong-path instructions fetched after a branch are cleanly removed from the pipeline.

## MS2 + MS3
### RISC-V Core (`riscv.v`)
- Worked jointly with John on the top-level core file, integrating all pipeline stages, control signals, and pipeline registers into a unified, functioning processor.
