mkfile_path := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))
BUILD_DIR  	?= $(mkfile_path)/work
BENDER_DIR	?= .
BENDER_NAME	?= bender
QUESTA      ?= #questa-2020.1
PYTHON		?= python

BENDER			?= $(BENDER_DIR)/$(BENDER_NAME)

compile_script 	?= scripts/compile.tcl
compile_flag  	?= -suppress 2583 -suppress 13314 -suppress 8386

sim_flags		?= -suppress 3999

#bender_defs += -D COREV_ASSERT_OFF

sim_targs += -t rtl
sim_targs += -t test
#bender_targs += -t cv32e40p_exclude_tracer
sim_targs += -t sfm_sim

INI_PATH  = $(mkfile_path)/modelsim.ini
WORK_PATH = $(BUILD_DIR)
WAVES	  = wave.do

tb := sfm_fp_glob_minmax_tb

gui      ?= 0

P_STALL_GEN ?= 0.0
P_STALL_RCV ?= 0.0

fpformat				?= BFLOAT16
a_fraction				?= 14
coefficient_fraction	?= 4
constant_fraction		?= 7
mul_surplus_bits		?= 1
not_surplus_bits		?= 0
n_inputs				?= 100
alpha					?= 0.218750000
beta					?= 0.410156250
gamma1					?= 2.835937500
gamma2					?= 2.167968750

# Run the simulation
run:
ifeq ($(gui), 0)
	$(QUESTA) vsim -c vopt_tb -do "run -a" 	\
	-gP_STALL_GEN=$(P_STALL_GEN)			\
	-gP_STALL_RCV=$(P_STALL_RCV)
else
	$(QUESTA) vsim vopt_tb        \
	-do "add log -r sim:/$(tb)/*" \
	-do "source $(WAVES)"         \
	-gP_STALL_GEN=$(P_STALL_GEN)  \
	-gP_STALL_RCV=$(P_STALL_RCV)  \
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
	$(PYTHON) golden-model/golden.py --fpformat $(fpformat) --a_fraction $(a_fraction) --coefficient_fraction $(coefficient_fraction) --constant_fraction $(constant_fraction) --mul_surplus_bits $(mul_surplus_bits) --not_surplus_bits $(mul_surplus_bits) --n_inputs $(n_inputs) --alpha $(alpha) --beta $(beta) --gamma1 $(gamma1) --gamma2 $(gamma2)