# riscv32Project - Icarus Verilog build
#
# Usage:
#   make run PROG=<name>  - assemble test/asm/<name>.s and run dump_tb on it
#   make asm PROG=<name>  - assemble test/asm/<name>.s into test/mem/<name>.hex
#   make test-<name>      - run test/asm/<name>.s against test/test_benches/<name>_tb.v
#   make clean

RTL_SRC := $(filter-out verilog/core/defines.v, \
             $(wildcard verilog/primitives/*.v) \
             $(wildcard verilog/core/*.v) \
             $(wildcard verilog/memory/*.v))

IVERILOG_FLAGS := -g2012 -I verilog/core
BUILD          := build

ASM_DIR := test/asm
MEM_DIR := test/mem
TB_DIR  := test/test_benches

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

# Keep generated .hex files -- make treats them as intermediates of test-%
# otherwise and deletes them after the run.
.PRECIOUS: $(MEM_DIR)/%.hex

$(BUILD):
	-@$(MKDIR) $(BUILD) $(NULL)

# --------------------------------------------------------------------------
# Assembly rule: test/asm/<name>.s -> test/mem/<name>.hex
# --------------------------------------------------------------------------
$(MEM_DIR)/%.hex: $(ASM_DIR)/%.s tools/asm.py
	$(ASM) $< $@

# --------------------------------------------------------------------------
# Ad-hoc programs: `make run PROG=simple` assembles test/asm/simple.s and
# runs dump_tb against it. No hard-coded expected values -- the dump
# prints every register so you can read the result.
# --------------------------------------------------------------------------
run: $(BUILD) $(MEM_DIR)/$(PROG).hex
	$(CP) $(call FIXPATH,$(MEM_DIR)/$(PROG).hex) $(call FIXPATH,$(MEM_DIR)/inst.hex)
	iverilog $(IVERILOG_FLAGS) -o $(BUILD)/dump $(RTL_SRC) $(TB_DIR)/dump_tb.v
	cd $(MEM_DIR) && vvp ../../$(BUILD)/dump

asm: $(MEM_DIR)/$(PROG).hex
	@echo "assembled $(ASM_DIR)/$(PROG).s -> $(MEM_DIR)/$(PROG).hex"

# --------------------------------------------------------------------------
# Named test: `make test-fibonacci` runs test/asm/fibonacci.s against
# test/test_benches/fibonacci_tb.v with pass/fail checks. Add new tests by
# writing test/asm/<name>.s plus test/test_benches/<name>_tb.v; this rule
# handles the rest.
# --------------------------------------------------------------------------
test-%: $(BUILD) $(MEM_DIR)/%.hex $(TB_DIR)/%_tb.v
	$(CP) $(call FIXPATH,$(MEM_DIR)/$*.hex) $(call FIXPATH,$(MEM_DIR)/inst.hex)
	iverilog $(IVERILOG_FLAGS) -o $(BUILD)/$* $(RTL_SRC) $(TB_DIR)/$*_tb.v
	cd $(MEM_DIR) && vvp ../../$(BUILD)/$*

clean:
	-$(RMRF) $(BUILD) $(NULL)
