# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Andrea Belano <andrea.belano@studio.unibo.it>
#

mkfile_path := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))
SW          ?= $(mkfile_path)sw
BUILD_DIR  	?= $(mkfile_path)/work
BENDER_DIR	?= .
BENDER_NAME	?= bender
QUESTA      ?= #questa-2020.1
PYTHON		?= python
ISA         ?= riscv
ARCH        ?= rv
XLEN        ?= 32
XTEN        ?= imc

BENDER		?= $(BENDER_DIR)/$(BENDER_NAME)
TEST		?= sfm.c

TEST_SRCS 	:= $(SW)/$(TEST)

compile_script 	?= scripts/compile.tcl
compile_flag  	?= -suppress 2583 -suppress 13314 -suppress 8386

sim_flags		?= -suppress 3999

bender_defs += -D COREV_ASSERT_OFF

sim_targs += -t rtl
sim_targs += -t test
bender_targs += -t cv32e40p_exclude_tracer
sim_targs += -t sfm_sim

INI_PATH  = $(mkfile_path)/modelsim.ini
WORK_PATH = $(BUILD_DIR)
WAVES	  = scripts/wave.tcl

tb := sfm_tb

gui      ?= 0

PROB_STALL ?= 0.0

# Include directories
INC += -I$(SW)
INC += -I$(SW)/inc
INC += -I$(SW)/utils

BOOTSCRIPT := $(SW)/kernel/crt0.S
LINKSCRIPT := $(SW)/kernel/link.ld

CC=$(ISA)$(XLEN)-unknown-elf-gcc
LD=$(CC)
OBJDUMP=$(ISA)$(XLEN)-unknown-elf-objdump
CC_OPTS=-march=$(ARCH)$(XLEN)$(XTEN) -mabi=ilp32 -D__$(ISA)__ -O2 -g -Wextra -Wall -Wno-unused-parameter -Wno-unused-variable -Wno-unused-function -Wundef -fdata-sections -ffunction-sections -MMD -MP
LD_OPTS=-march=$(ARCH)$(XLEN)$(XTEN) -mabi=ilp32 -D__$(ISA)__ -MMD -MP -nostartfiles -nostdlib -Wl,--gc-sections

# Setup build object dirs
CRT=$(BUILD_DIR)/crt0.o
OBJ=$(BUILD_DIR)/verif.o
BIN=$(BUILD_DIR)/verif
DUMP=$(BUILD_DIR)/verif.dump

STIM_INSTR=$(mkfile_path)/stim_instr.txt
STIM_DATA=$(mkfile_path)/stim_data.txt

# Build implicit rules
$(STIM_INSTR) $(STIM_DATA): $(BIN)
	objcopy --srec-len 1 --output-target=srec $(BIN) $(BIN).s19
	scripts/parse_s19.pl $(BIN).s19 > $(BIN).txt
	python scripts/s19tomem.py $(BIN).txt $(STIM_INSTR) $(STIM_DATA)

$(BIN): $(CRT) $(OBJ)
	$(LD) $(LD_OPTS) -o $(BIN) $(CRT) $(OBJ) -T$(LINKSCRIPT)

$(CRT): $(BUILD_DIR)
	$(CC) $(CC_OPTS) -c $(BOOTSCRIPT) -o $(CRT)

$(OBJ): $(TEST_SRCS)
	$(CC) $(CC_OPTS) -c $(TEST_SRCS) $(FLAGS) $(INC) -o $(OBJ)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Generate instructions and data stimuli
sw-build: $(STIM_INSTR) $(STIM_DATA) dis

sw-clean:
	rm -f $(BUILD_DIR)/*.o

sw-all: sw-clean sw-build 

dis:
	$(OBJDUMP) -d $(BIN) > $(DUMP)

fpformat	?= BFLOAT16
length		?= 1024
range 		?= 128
monotonic	?= 0
step		?= 1

# Run the simulation
run:
ifeq ($(gui), 0)
	$(QUESTA) vsim -c vopt_tb -do "run -a" 	\
	-gPROB_STALL=$(PROB_STALL)				\
	$(sim_flags)
else
	$(QUESTA) vsim vopt_tb        	\
	-do "add log -r sim:/$(tb)/*" 	\
	-do "source $(WAVES)"         	\
	-gPROB_STALL=$(PROB_STALL)		\
	$(sim_flags)
endif

bender:
	curl --proto '=https'  \
	--tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh -s

update-ips:
	$(BENDER) update
	$(BENDER) script vsim          \
	--vlog-arg="$(compile_flag)"   \
	--vcom-arg="-pedanticerrors"   \
	$(bender_targs) $(bender_defs) \
	$(sim_targs)    $(sim_deps)    \
	> ${compile_script}

hw-opt:
	$(QUESTA) vopt +acc=npr -o vopt_tb $(tb) -floatparameters+$(tb) -work $(BUILD_DIR)

hw-compile:
	$(QUESTA) vsim -c +incdir+$(UVM_HOME) -do 'quit -code [source $(compile_script)]'

hw-lib:
	@touch modelsim.ini
	@mkdir -p $(BUILD_DIR)
	@$(QUESTA) vlib $(BUILD_DIR)
	@$(QUESTA) vmap work $(BUILD_DIR)
	@chmod +w modelsim.ini

hw-clean:
	rm -rf transcript
	rm -rf modelsim.ini

hw-all: hw-clean hw-lib hw-compile hw-opt

golden-clean:
	rm -rf golden-model/input.txt
	rm -rf golden-model/result.txt

golden: golden-clean
	mkdir -p sw/golden-model/
	$(PYTHON) golden-model/golden.py --fpformat $(fpformat) --length $(length) --range $(range) --monotonic $(monotonic) --step $(step)