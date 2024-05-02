# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Andrea Belano <andrea.belano@studio.unibo.it>
#

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -group wrap /sfm_tb/i_sfm_wrap/*
add wave -group wrap -group top /sfm_tb/i_sfm_wrap/i_top/*

add wave -group wrap -group top -group streamer /sfm_tb/i_sfm_wrap/i_top/i_streamer/*
add wave -group wrap -group top -group streamer -group ldst_mux /sfm_tb/i_sfm_wrap/i_top/i_streamer/i_ldst_mux/*
add wave -group wrap -group top -group streamer -group load_strb_gen /sfm_tb/i_sfm_wrap/i_top/i_streamer/i_load_strb_gen/*
add wave -group wrap -group top -group streamer -group store_strb_gen /sfm_tb/i_sfm_wrap/i_top/i_streamer/i_store_strb_gen/*
add wave -group wrap -group top -group streamer -group input_cast /sfm_tb/i_sfm_wrap/i_top/i_streamer/i_cast_in/*
add wave -group wrap -group top -group streamer -group output_cast /sfm_tb/i_sfm_wrap/i_top/i_streamer/i_cast_out/*

add wave  -group wrap -group top -group ctrl /sfm_tb/i_sfm_wrap/i_top/i_ctrl/*
add wave -group wrap -group top -group ctrl -group ctrl_slave /sfm_tb/i_sfm_wrap/i_top/i_ctrl/i_slave/*

add wave -r -group wrap -group top -group slot_regfile /sfm_tb/i_sfm_wrap/i_top/i_slot_regfile/*

add wave -group wrap -group top -group datapath /sfm_tb/i_sfm_wrap/i_top/i_datapath/*
add wave -group wrap -group top -group datapath -group glob_max /sfm_tb/i_sfm_wrap/i_top/i_datapath/i_global_maximum/*
add wave -group wrap -group top -group datapath -group scal_exp /sfm_tb/i_sfm_wrap/i_top/i_datapath/i_scal_exp/*
add wave -group wrap -group top -group datapath -group addmul /sfm_tb/i_sfm_wrap/i_top/i_datapath/i_addmul_time_mux/*
add wave -group wrap -group top -group datapath -group vect_exp /sfm_tb/i_sfm_wrap/i_top/i_datapath/i_vect_exp/*
add wave -group wrap -group top -group datapath -group red_sum /sfm_tb/i_sfm_wrap/i_top/i_datapath/i_vect_sum/*
add wave -group wrap -group top -group datapath -group denominator_accumulator /sfm_tb/i_sfm_wrap/i_top/i_datapath/i_denominator_accumulator/*
add wave -group wrap -group top -group datapath -group denominator_accumulator -group accumulator_ctrl /sfm_tb/i_sfm_wrap/i_top/i_datapath/i_denominator_accumulator/i_acc_ctrl/*
add wave -group wrap -group top -group datapath -group denominator_accumulator -group accumulator_datapath /sfm_tb/i_sfm_wrap/i_top/i_datapath/i_denominator_accumulator/i_acc_datapath/*
add wave -group wrap -group top -group datapath -group denominator_accumulator -group accumulator_datapath -group denominator_inverter /sfm_tb/i_sfm_wrap/i_top/i_datapath/i_denominator_accumulator/i_acc_datapath/i_denominator_inverter/*