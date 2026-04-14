# Verilog HDL RTL Modeling Guidelines (v1.0)

*Author: Mohamed Shalan*

**Legend:**
- **R (Rule):** required practice — **must** be implemented.
- **G (Guideline):** recommended practice — up to the designer.

## General

- **R:** Use indentation to improve readability.
- **R:** One Verilog statement per line.
- **R:** Keep line length ≤ 80 characters.
- **R:** One module per file. Name the file after the module (e.g. module `smul` → `smul.v`).

## Commenting

- **R:** Comment your code. Be reasonable — too many or too few both have drawbacks.
- **G:** Use `/* ... */` for multi-line comments.
- **R:** Add this header to the top of every source file:

  ```verilog
  /*******************************************************************
  *
  * Module: module_name.v
  * Project: Project_Name
  * Author: name and email
  * Description: put your description here
  *
  * Change history: 01/01/17 – Did something
  *                 10/29/17 – Did something else
  *
  **********************************************************************/
  ```

## Naming

- **R:** Create a naming convention, document it, and use it consistently.
- **G:** Capitals for constants: `STATE_S0`, `GO`, `ZERO`, ...
- **G:** Lowercase for signal, variable, and port names.
- **G:** All parameter names in capitals.
- **R:** Do **not** use hard-coded numeric values — use `` `define ``.
- **R:** Do **not** declare `` `define `` in individual modules. Put global `` `define ``s in external definition files included via `` `include ``.
- **G:** Active-low signals end with `_` plus a lowercase char (e.g. `_b` or `_n`).
- **R:** Use a consistent bit-ordering convention for multibit buses.

## Module Declaration / Instantiation

- **R:** At most one module per file.
- **R:** Each module in its own file.
- **R:** Declare inputs and outputs one per line.
- **G:** Port declaration order:
  1. Clocks
  2. Resets
  3. Enables
  4. Other control signals
  5. Data and address lines
- **G:** Group ports logically by function.
- **R:** `inout` ports **cannot** be used to create tri-state buses (Yosys does not support tri-state logic).
- **R:** Do **not** use positional arguments for instantiation — always use dot notation (connect ports by name).
- **R:** Port connection widths must match.
- **R:** No expressions in port connections.
- **R:** Drive all unused module inputs.
- **R:** Connect unused module outputs.
- **G:** Parameterize modules if appropriate and readability isn't hurt.

## Clocking

- **R:** Core clock signal is `clk`.
- **G:** Non-core clocks should have descriptive names including frequency (e.g. `clk_ssp_625`).
- **G:** One clock per module if possible.
- **G:** Avoid mixed clock edges if possible.
- **R:** Do **not** gate the clocks.

## Resetting

- **R:** Always reset sequential modules — resets make the design deterministic and verifiable.
- **R:** Use **asynchronous active-high reset** unless the target technology doesn't support it.
- **G:** Use `rst` for the module reset signal.

## Modeling

- **R:** Blocking assignments **only** for combinational logic (`always_comb`).
- **R:** Non-blocking assignments **only** for sequential logic (`always_ff`).
- **R:** Don't mix blocking and non-blocking in one block. Separate combinational from sequential.
- **R:** Do not assign to the same variable from different `always` blocks (race conditions).
- **R:** One clock per always sensitivity list.
- **R:** Use `@*` as the sensitivity list for combinational `always` blocks.
- **R:** `$signed()` may only wrap operands to `>>>`, `>`, `>=`, `<`, `<=` to get signed equivalents.
- **R:** Wires must be declared before use.
- **G:** Use `generate` blocks to generate hardware via loops.
- **G:** Avoid the `*` (multiplication) operator for large multipliers — design an optimized multiplier instead. Small multipliers synthesize fine.
- **G:** Use one of the recommended FSM templates (see reference [1]).
- **R:** **Avoid LATCHES!** Check synthesis results for inferred latches — they usually mean something was missed. To avoid:
  - Every `if` has an `else`.
  - Every `case` has a `default`.
  - All signals initialized within a combinational block.
- **R:** Do **not** use `casex` in RTL.
- **R:** `casez` only in specific priority-encoder cases.
- **R:** No asynchronous logic / combinational feedback loops / self-timed logic.
- **R:** Don't hand-instantiate standard library cells in RTL.
- **R:** Synchronize any asynchronous input — 2-FF brute-force synchronizer for single signals. See [2] for buses.
- **R:** Synchronize any signal crossing clock domains. Brute-force for slower→faster; see [2] for other cases.
- **G:** Eliminate glue logic at the top level.
- **R:** Do not assign `x` to signals.
- **R:** Operand sizes must match.
- **R:** Verilog primitives cannot be used.
- **R:** Use parentheses in complex equations.
- **R:** Avoid unbounded loops.

## Memory

- **R:** Do not use large arrays. For SRAM blocks, use the provided memory blocks and interface them to the module that needs them.

## Test Benching

- **R:** Name the testbench file after the module + `_tb` (e.g. `smul_tb.v`).
- **R:** `initial` shall **not** be used in RTL modeling — testbenches only. Use reset to initialize registers.
- **R:** Delays shall **not** be used in RTL — testbenches only.
- **G:** In the testbench, sample before the clock edge and drive after the clock edge.

---

## References

1. Clifford E. Cummings, *The Fundamentals of Efficient Synthesizable Finite State Machine Design*.
2. Clifford E. Cummings, *Clock Domain Crossing (CDC) Design & Verification Techniques Using SystemVerilog*.
3. OpenCores, *HDL Modeling Guidelines*.
4. Lattice Semiconductor, *HDL Coding Guidelines*.
5. Microsemi, *Actel HDL Coding Style Guide*.
