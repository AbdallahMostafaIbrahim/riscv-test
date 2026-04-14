# CSCE 3301 – Computer Architecture (Spring 2026)

## Project 1: femtoRV32 — RISC-V FPGA Implementation and Testing

## 1. Requirements

Implement a RISC-V processor and test it on the **Nexys A7** trainer kit. The implementation must satisfy:

1. **RV32I base integer instruction set** per the specifications at <https://riscv.org/specifications/ratified/>. All **forty-two** user-level instructions (Chapter 36, pages 585–586 of "The RISC-V Instruction Set Manual Volume I: Unprivileged Architecture", Version 20260120; explained in Chapter 2) must be implemented **except**:
   - `ECALL`, `EBREAK`, `PAUSE`, `FENCE`, and `FENCE.TSO`
   - These 5 must instead be treated as **halting instructions** that end program execution (PC stops updating).

2. **Pipelined** with correct hazard handling.

3. **Single, single-ported, byte-addressable memory** for both data and instructions. This structural hazard is handled by issuing an instruction every 2 clock cycles (effective CPI = 2):
   - Each instruction executes in 6 cycles divided into 3 stages of 2 clock cycles (C0 and C1):
     - **Stage 0:** Instruction Fetch (C0) and Register read (C1)
     - **Stage 1:** ALU operation (C0) and Memory read/write (C1)
     - **Stage 2:** Register write back (C0); C1 unused

4. **Test cases** demonstrating full support of all instructions and all hazard scenarios. Code segments from the RISC-V official compliance test suite may optionally be used: <https://gitlab.com/incoresemi/riscof/-/tree/master/riscof/suite/rv32i_m/I>

**Important:** Provided Verilog descriptions model the ALU, Immediate generator, and a general constant definitions file. Understand each before using.

## 2. Bonus Features (up to 2)

Each bonus is worth 5% (max 10%):

1. Support **compressed instructions** (RV32IC) — except those that don't map to supported instructions.
2. Support **integer multiplication and division** (RV32IM).
3. **2-bit dynamic branch prediction** (including branch target address prediction).
4. Move **branch outcome and target address computation to the ID stage** and handle resulting data hazards.
5. Alternative solution to the **single single-ported memory structural hazard** (other than every-other-cycle issuing).
6. **Test program generator** that emits random but valid instruction sequences (any language).

## 3. General Guidelines

- Work with your lab partner. Select a **team leader** responsible for submissions. Any member may interact with the instructor/TA.
- Every member must keep a **journal** (text file) logging activities. Example:
  ```
  April 18, 1:55PM: finished the forwarding unit.
                   Fixed issue in pipelining registers.
  ```
- Every deliverable (after MS1) is a single zip containing:
  - `readme.txt` — student names, release notes (issues, assumptions, what works/doesn't)
  - `journal/` — journal file per member
  - `Verilog/` — all Verilog descriptions
  - `test/` — test files
  - **PDF report** — design (datapath schematic), implementation, issues, solutions, waveform screenshots, etc.
- Follow the **Verilog coding guidelines** document.

## 4. Deliverables

| Milestone | Due | Contents |
|-----------|-----|----------|
| MS1 (Done) | — | Team names, IDs |
| MS2 | Thu Apr 16 | Single-cycle datapath block diagram + Verilog for all RV32I (as above). Basic tests covering all instructions. Separate instruction/data memories allowed. No thorough testing required. FPGA testing optional. |
| MS3 | Thu Apr 23 | Pipelined datapath block diagram + Verilog. **Single single-ported memory** for instructions and data. Final implementation and report with proof of thorough FPGA testing (all 42 instructions + hazards) and any bonuses. |
| Demo | TBA | Reserve slot via shared Google sheet. Run at least one test case and answer implementation/report questions. |

## 5. Grading

- Project 1 = **25%** of course marks (Project 2 = 15%; total 40%).
- Distribution out of 100:
  - MS1: 5%
  - MS2: 15%
  - MS3: 80%
  - Bonuses: +5% each, max +10%
- **Deductions:**
  - −5% for not complying with coding guidelines
  - −5% for not following submission directory structure
  - −5% per late milestone (one day max)
  - −100% for plagiarism
- Group members may receive different grades based on contribution.
