# Journal — Abdallah Mostafa Ibrahim (900232544)

Activity log for Project 1 (riscv32Project). Format follows the
project description example.

---

April 14, 10:30 AM: Project kickoff with John. Agreed on directory
                    layout, naming conventions, and to keep all
                    Verilog constants in a single `defines.v`.
                    Set up git repo and initial Makefile. Sketched
                    the single-cycle datapath on paper.

April 14, 03:00 PM: Implemented primitive building blocks
                    (flip_flop, register, full_adder, ripple, mux,
                    sign_extender). Wrote reg_file with
                    synchronous write, hard-wired x0 read, and
                    async reset. Stubbed inst_mem / data_mem with
                    `$readmemh` init.

April 14, 08:00 PM: Wrote the vivado project tcl so anyone can
                    regenerate the FPGA project.

April 15, 09:45 AM: Implemented the control_unit as a flat
                    opcode -> signals decoder. Covered all 37
                    user opcodes plus the five halt opcodes.
                    First pass used a 5-bit alu_sel; later
                    rewrote to the 4-bit encoding in defines.v.

April 15, 11:20 AM: Immediate generator covering I/S/B/U/J
                    formats. Verified by running the pre-existing
                    default.s coverage program.

April 15, 01:15 PM: Byte-addressable data memory. Moved the
                    byte-lane mask from inside data_mem into a
                    dedicated store_unit so data_mem stays dumb.
                    Built a matching load_unit that does the
                    inverse (byte / half selection + sign/zero
                    extension).

April 15, 03:50 PM: Wrote per-instruction-type test programs
                    (i-type.s ... j-type.s) and matching
                    self-checking testbenches. All seven pass
                    plus isa_tb and fibonacci_tb.

April 15, 06:30 PM: Refactor pass: renamed `wstrb` -> write_mask
                    and `addr_lo` -> addr_low for readability;
                    centralised every magic number behind a
                    `define` (opcodes, funct3, branch codes,
                    ALU codes, instruction-field slices).

April 15, 09:00 PM: Started writing this README / REPORT /
                    journal ahead of the MS2 deadline.

---

*Add further entries below as MS3 work begins.*
