#!/usr/bin/env python3
"""
Minimal RV32I assembler for femtoRV32.

Supports every instruction the core implements:
    ADD  SUB  SLL  SLT  SLTU  XOR  SRL  SRA  OR  AND
    ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI
    LB LH LW LBU LHU
    SB SH SW
    BEQ BNE BLT BGE BLTU BGEU
    LUI AUIPC
    JAL JALR
    ECALL EBREAK FENCE FENCE.TSO PAUSE   (all halt the core)
    NOP                                   (alias for addi x0, x0, 0)

Syntax
------
  Standard RISC-V assembly, ABI or x-register names:
      addi x1, x0, 5
      addi a0, zero, 10
      lw   t0, 8(sp)
      beq  x1, x2, target

  Labels end with ':'. Branch / jump targets may be labels or numeric
  PC-relative byte offsets (0x, decimal, or negative):
      loop:
          addi x1, x1, -1
          bne  x1, x0, loop

Comments start with '#'. One instruction per line.

Usage:
    tools/asm.py input.s [output.hex]
If output is omitted, hex is written to stdout.
"""

import sys
import re


# --------------------------------------------------------------------------
# Register name table (ABI + numeric)
# --------------------------------------------------------------------------
ABI = dict(
    zero=0, ra=1, sp=2, gp=3, tp=4,
    t0=5, t1=6, t2=7,
    s0=8, fp=8, s1=9,
    a0=10, a1=11, a2=12, a3=13, a4=14, a5=15, a6=16, a7=17,
    s2=18, s3=19, s4=20, s5=21, s6=22, s7=23, s8=24, s9=25,
    s10=26, s11=27,
    t3=28, t4=29, t5=30, t6=31,
)


def parse_reg(tok: str) -> int:
    t = tok.strip().lower()
    if t in ABI:
        return ABI[t]
    m = re.fullmatch(r"x(\d+)", t)
    if m:
        n = int(m.group(1))
        if 0 <= n < 32:
            return n
    raise SyntaxError(f"bad register name: {tok!r}")


def parse_imm(tok: str, bits: int, signed: bool = True) -> int:
    t = tok.strip()
    v = int(t, 0)
    if signed:
        lo = -(1 << (bits - 1))
        hi = (1 << (bits - 1)) - 1
        if not (lo <= v <= hi):
            raise OverflowError(
                f"immediate {v} out of signed {bits}-bit range")
        v &= (1 << bits) - 1
    else:
        if not (0 <= v < (1 << bits)):
            raise OverflowError(
                f"immediate {v} out of unsigned {bits}-bit range")
    return v


# --------------------------------------------------------------------------
# Encoders per instruction format
# --------------------------------------------------------------------------
def r_type(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def i_type(imm12, rs1, f3, rd, op):
    return ((imm12 & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def s_type(imm12, rs2, rs1, f3, op):
    hi = (imm12 >> 5) & 0x7F
    lo = imm12 & 0x1F
    return (hi << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (lo << 7) | op


def b_type(imm13, rs2, rs1, f3, op):
    # imm13 is 13-bit signed byte offset; bit 0 is always zero
    b12 = (imm13 >> 12) & 1
    b11 = (imm13 >> 11) & 1
    b10_5 = (imm13 >> 5) & 0x3F
    b4_1 = (imm13 >> 1) & 0xF
    return ((b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15)
            | (f3 << 12) | (b4_1 << 8) | (b11 << 7) | op)


def u_type(imm20, rd, op):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op


def j_type(imm21, rd, op):
    b20 = (imm21 >> 20) & 1
    b10_1 = (imm21 >> 1) & 0x3FF
    b11 = (imm21 >> 11) & 1
    b19_12 = (imm21 >> 12) & 0xFF
    return ((b20 << 31) | (b10_1 << 21) | (b11 << 20) | (b19_12 << 12)
            | (rd << 7) | op)


# --------------------------------------------------------------------------
# Instruction dispatch table
#   tuple kind = type marker, followed by format-specific constants
# --------------------------------------------------------------------------
OPS = {
    # R-type: ('R', funct7, funct3, opcode)
    'add':  ('R', 0x00, 0, 0x33),
    'sub':  ('R', 0x20, 0, 0x33),
    'sll':  ('R', 0x00, 1, 0x33),
    'slt':  ('R', 0x00, 2, 0x33),
    'sltu': ('R', 0x00, 3, 0x33),
    'xor':  ('R', 0x00, 4, 0x33),
    'srl':  ('R', 0x00, 5, 0x33),
    'sra':  ('R', 0x20, 5, 0x33),
    'or':   ('R', 0x00, 6, 0x33),
    'and':  ('R', 0x00, 7, 0x33),

    # I-ALU (non-shift): ('I', funct3, opcode)
    'addi':  ('I', 0, 0x13),
    'slti':  ('I', 2, 0x13),
    'sltiu': ('I', 3, 0x13),
    'xori':  ('I', 4, 0x13),
    'ori':   ('I', 6, 0x13),
    'andi':  ('I', 7, 0x13),

    # I-shifts: ('IS', funct3, funct7, opcode)
    'slli': ('IS', 1, 0x00, 0x13),
    'srli': ('IS', 5, 0x00, 0x13),
    'srai': ('IS', 5, 0x20, 0x13),

    # Loads: ('L', funct3, opcode)
    'lb':  ('L', 0, 0x03),
    'lh':  ('L', 1, 0x03),
    'lw':  ('L', 2, 0x03),
    'lbu': ('L', 4, 0x03),
    'lhu': ('L', 5, 0x03),

    # Stores: ('S', funct3, opcode)
    'sb': ('S', 0, 0x23),
    'sh': ('S', 1, 0x23),
    'sw': ('S', 2, 0x23),

    # Branches: ('B', funct3, opcode)
    'beq':  ('B', 0, 0x63),
    'bne':  ('B', 1, 0x63),
    'blt':  ('B', 4, 0x63),
    'bge':  ('B', 5, 0x63),
    'bltu': ('B', 6, 0x63),
    'bgeu': ('B', 7, 0x63),

    # U-type
    'lui':   ('U', 0x37),
    'auipc': ('U', 0x17),

    # Jumps
    'jal':  ('J',  0x6F),
    'jalr': ('JR', 0, 0x67),

    # Halting pseudo / system ops: fixed encodings
    'ecall':     ('FIXED', 0x00000073),
    'ebreak':    ('FIXED', 0x00100073),
    'fence':     ('FIXED', 0x0000000F),
    'fence.tso': ('FIXED', 0x8330000F),
    'pause':     ('FIXED', 0x0100000F),
    'nop':       ('FIXED', 0x00000013),
}


def resolve_target(tok: str, pc: int, labels: dict) -> int:
    t = tok.strip()
    if t in labels:
        return labels[t] - pc
    return int(t, 0)


def split_operands(s: str):
    # Split on comma, whitespace, or parens so "lw x1, 4(x2)" ->
    # ['lw', 'x1', '4', 'x2']
    return [p for p in re.split(r"[,\s()]+", s.strip()) if p]


def assemble(lines):
    # Pass 1: strip comments, record labels, compute PC for each instr.
    pc = 0
    labels = {}
    prepped = []
    for lineno, raw in enumerate(lines, 1):
        stripped = raw.split('#', 1)[0].strip()
        if not stripped:
            continue
        # Handle one or more labels at the start of the line.
        while ':' in stripped:
            head, tail = stripped.split(':', 1)
            label = head.strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", label):
                raise SyntaxError(
                    f"line {lineno}: bad label {label!r}")
            labels[label] = pc
            stripped = tail.strip()
            if not stripped:
                break
        if not stripped:
            continue
        prepped.append((lineno, pc, stripped))
        pc += 4

    # Pass 2: encode.
    words = []
    for lineno, pc, text in prepped:
        try:
            words.append(encode_one(pc, text, labels))
        except Exception as e:
            raise SyntaxError(f"line {lineno}: {e}") from None
    return words


def encode_one(pc, text, labels):
    parts = split_operands(text)
    mnem = parts[0].lower()
    if mnem not in OPS:
        raise SyntaxError(f"unknown instruction {mnem!r}")
    spec = OPS[mnem]
    kind = spec[0]

    if kind == 'R':
        _, f7, f3, op = spec
        rd  = parse_reg(parts[1])
        rs1 = parse_reg(parts[2])
        rs2 = parse_reg(parts[3])
        return r_type(f7, rs2, rs1, f3, rd, op)

    if kind == 'I':     # ADDI-family: rd, rs1, imm
        _, f3, op = spec
        rd  = parse_reg(parts[1])
        rs1 = parse_reg(parts[2])
        iv  = parse_imm(parts[3], 12, signed=True)
        return i_type(iv, rs1, f3, rd, op)

    if kind == 'IS':    # SLLI / SRLI / SRAI: rd, rs1, shamt
        _, f3, f7, op = spec
        rd  = parse_reg(parts[1])
        rs1 = parse_reg(parts[2])
        sh  = parse_imm(parts[3], 5, signed=False)
        iv  = (f7 << 5) | sh
        return i_type(iv, rs1, f3, rd, op)

    if kind == 'L':     # LW-family: rd, offset(rs1)
        _, f3, op = spec
        rd  = parse_reg(parts[1])
        iv  = parse_imm(parts[2], 12, signed=True)
        rs1 = parse_reg(parts[3])
        return i_type(iv, rs1, f3, rd, op)

    if kind == 'S':     # SW-family: rs2, offset(rs1)
        _, f3, op = spec
        rs2 = parse_reg(parts[1])
        iv  = parse_imm(parts[2], 12, signed=True)
        rs1 = parse_reg(parts[3])
        return s_type(iv, rs2, rs1, f3, op)

    if kind == 'B':     # BEQ-family: rs1, rs2, target
        _, f3, op = spec
        rs1 = parse_reg(parts[1])
        rs2 = parse_reg(parts[2])
        off = resolve_target(parts[3], pc, labels)
        if off & 1:
            raise ValueError("branch offset must be even")
        iv  = parse_imm(str(off), 13, signed=True)
        return b_type(iv, rs2, rs1, f3, op)

    if kind == 'U':     # LUI / AUIPC: rd, imm20
        _, op = spec
        rd = parse_reg(parts[1])
        iv = parse_imm(parts[2], 20, signed=False)
        return u_type(iv, rd, op)

    if kind == 'J':     # JAL: rd, target
        _, op = spec
        rd  = parse_reg(parts[1])
        off = resolve_target(parts[2], pc, labels)
        iv  = parse_imm(str(off), 21, signed=True)
        return j_type(iv, rd, op)

    if kind == 'JR':    # JALR: rd, offset(rs1)
        _, f3, op = spec
        rd  = parse_reg(parts[1])
        iv  = parse_imm(parts[2], 12, signed=True)
        rs1 = parse_reg(parts[3])
        return i_type(iv, rs1, f3, rd, op)

    if kind == 'FIXED':
        _, word = spec
        return word

    raise SyntaxError(f"unhandled instruction kind {kind}")


# --------------------------------------------------------------------------
def main(argv):
    if len(argv) < 2:
        sys.stderr.write(__doc__)
        return 1
    in_path = argv[1]
    out_path = argv[2] if len(argv) > 2 else None

    with open(in_path) as f:
        words = assemble(f.readlines())

    text = "\n".join(f"{w:08x}" for w in words) + "\n"
    if out_path is None:
        sys.stdout.write(text)
    else:
        with open(out_path, "w") as f:
            f.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
