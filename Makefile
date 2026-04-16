# riscv32Project - Icarus Verilog build
#
# Usage:
#   make run PROG=<name>  - assemble tests/<name>.s and run dump_tb on it
#   make asm PROG=<name>  - assemble tests/<name>.s into mem/<name>.hex
#   make test-<name>      - run tests/<name>.s against test/<name>_tb.v
#   make clean

RTL_SRC := $(filter-out rtl/core/defines.v, \
             $(wildcard rtl/primitives/*.v) \
             $(wildcard rtl/core/*.v) \
             $(wildcard rtl/memory/*.v))

IVERILOG_FLAGS := -g2012 -I rtl/core
BUILD          := build

# Detect shell: Windows cmd vs a Unix-like shell (bash/sh/zsh on any OS).
# $(OS) is Windows_NT inside Git Bash too, so we probe the shell instead
# by running `echo` -- cmd's echo with no args prints "ECHO is on.", Unix
# echo prints an empty line.
ifeq ($(shell echo),)
  IS_UNIX_SHELL := 1
else
  IS_UNIX_SHELL := 0
endif

ifeq ($(IS_UNIX_SHELL),1)
  CP      := cp
  RMRF    := rm -rf
  RMFILE  := rm -f
  MKDIR   := mkdir -p
  PYTHON  := python3
  FIXPATH  = $1
  NULL    := 2>/dev/null
else
  CP      := copy /Y
  RMRF    := rmdir /S /Q
  RMFILE  := del /Q /F
  MKDIR   := mkdir
  PYTHON  := python
  FIXPATH  = $(subst /,\,$1)
  NULL    := 2> NUL
endif

ASM := $(PYTHON) tools/asm.py

# Default program for the regression testbench
DEFAULT_PROG := default

# User-selected program for `make run` / `make asm`
PROG ?= $(DEFAULT_PROG)

.PHONY: run asm clean

$(BUILD):
	-@$(MKDIR) $(BUILD) $(NULL)

# --------------------------------------------------------------------------
# Assembly rule: tests/<name>.s -> mem/<name>.hex
# --------------------------------------------------------------------------
mem/%.hex: tests/%.s tools/asm.py
	$(ASM) $< $@

# --------------------------------------------------------------------------
# Ad-hoc programs: `make run PROG=simple` assembles tests/simple.s and
# runs dump_tb against it. No hard-coded expected values -- the dump
# prints every register so you can read the result.
# --------------------------------------------------------------------------
run: $(BUILD) mem/$(PROG).hex
	$(CP) $(call FIXPATH,mem/$(PROG).hex) $(call FIXPATH,mem/inst.hex)
	iverilog $(IVERILOG_FLAGS) -o $(BUILD)/dump $(RTL_SRC) test/dump_tb.v
	cd mem && vvp ../$(BUILD)/dump

asm: mem/$(PROG).hex
	@echo "assembled tests/$(PROG).s -> mem/$(PROG).hex"

# --------------------------------------------------------------------------
# Named test: `make test-fibonacci` runs tests/fibonacci.s against
# test/fibonacci_tb.v with pass/fail checks. Add new tests by writing
# tests/<name>.s plus test/<name>_tb.v; this rule handles the rest.
# --------------------------------------------------------------------------
test-%: $(BUILD) mem/%.hex test/%_tb.v
	$(CP) $(call FIXPATH,mem/$*.hex) $(call FIXPATH,mem/inst.hex)
	iverilog $(IVERILOG_FLAGS) -o $(BUILD)/$* $(RTL_SRC) test/$*_tb.v
	cd mem && vvp ../$(BUILD)/$*

clean:
	-$(RMRF) $(BUILD) $(NULL)
	-$(RMFILE) $(call FIXPATH,mem/inst.hex) $(NULL)
