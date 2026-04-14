# femtoRV32 - Icarus Verilog build
#
# Usage:
#   make            - run both testbenches
#   make integ      - run the integration testbench only
#   make isa        - run the ISA-table testbench only
#   make wave       - re-run integ with VCD dump
#   make clean

RTL_SRC := $(wildcard rtl/primitives/*.v) \
           $(wildcard rtl/core/*.v) \
           $(wildcard rtl/memory/*.v)

IVERILOG_FLAGS := -g2012

BUILD := build

.PHONY: all integ isa wave clean

all: integ isa

$(BUILD):
	@mkdir -p $(BUILD)

integ: $(BUILD)
	iverilog $(IVERILOG_FLAGS) -o $(BUILD)/integ $(RTL_SRC) test/riscv_tb.v
	cd mem && vvp ../$(BUILD)/integ

isa: $(BUILD)
	iverilog $(IVERILOG_FLAGS) -o $(BUILD)/isa $(RTL_SRC) test/isa_tb.v
	cd mem && vvp ../$(BUILD)/isa

wave: $(BUILD)
	iverilog $(IVERILOG_FLAGS) -DDUMP_VCD -o $(BUILD)/integ_wave $(RTL_SRC) test/riscv_tb.v
	cd mem && vvp ../$(BUILD)/integ_wave

clean:
	rm -rf $(BUILD)
