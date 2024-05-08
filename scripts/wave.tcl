# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Andrea Belano <andrea.belano@studio.unibo.it>
#

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -group wrap /softex_tb/i_softex_wrap/*
add wave -group wrap -group top /softex_tb/i_softex_wrap/i_top/*

add wave -group wrap -group top -group streamer /softex_tb/i_softex_wrap/i_top/i_streamer/*
add wave -group wrap -group top -group streamer -group in_stream /softex_tb/i_softex_wrap/i_top/i_streamer/in_stream_o/*
add wave -group wrap -group top -group streamer -group out_stream /softex_tb/i_softex_wrap/i_top/i_streamer/out_stream_i/*
add wave -group wrap -group top -group streamer -group slot_in_stream /softex_tb/i_softex_wrap/i_top/i_streamer/slot_in_stream_o/*
add wave -group wrap -group top -group streamer -group slot_out_stream /softex_tb/i_softex_wrap/i_top/i_streamer/slot_out_stream_i/*
add wave -group wrap -group top -group streamer -group ldst_mux /softex_tb/i_softex_wrap/i_top/i_streamer/i_ldst_mux/*
add wave -group wrap -group top -group streamer -group load_strb_gen /softex_tb/i_softex_wrap/i_top/i_streamer/i_load_strb_gen/*
add wave -group wrap -group top -group streamer -group store_strb_gen /softex_tb/i_softex_wrap/i_top/i_streamer/i_store_strb_gen/*
add wave -group wrap -group top -group streamer -group input_cast /softex_tb/i_softex_wrap/i_top/i_streamer/i_cast_in/*
add wave -group wrap -group top -group streamer -group output_cast /softex_tb/i_softex_wrap/i_top/i_streamer/i_cast_out/*

add wave  -group wrap -group top -group ctrl /softex_tb/i_softex_wrap/i_top/i_ctrl/*
add wave -group wrap -group top -group ctrl -group ctrl_slave /softex_tb/i_softex_wrap/i_top/i_ctrl/i_slave/*

add wave -r -group wrap -group top -group slot_regfile /softex_tb/i_softex_wrap/i_top/i_slot_regfile/*

add wave -group wrap -group top -group datapath /softex_tb/i_softex_wrap/i_top/i_datapath/*
add wave -group wrap -group top -group datapath -group glob_max /softex_tb/i_softex_wrap/i_top/i_datapath/i_global_maximum/*
add wave -group wrap -group top -group datapath -group scal_exp /softex_tb/i_softex_wrap/i_top/i_datapath/i_scal_exp/*
add wave -group wrap -group top -group datapath -group addmul /softex_tb/i_softex_wrap/i_top/i_datapath/i_addmul_time_mux/*
add wave -group wrap -group top -group datapath -group vect_exp /softex_tb/i_softex_wrap/i_top/i_datapath/i_vect_exp/*
add wave -group wrap -group top -group datapath -group red_sum /softex_tb/i_softex_wrap/i_top/i_datapath/i_vect_sum/*
add wave -group wrap -group top -group datapath -group denominator_accumulator /softex_tb/i_softex_wrap/i_top/i_datapath/i_denominator_accumulator/*
add wave -group wrap -group top -group datapath -group denominator_accumulator -group accumulator_ctrl /softex_tb/i_softex_wrap/i_top/i_datapath/i_denominator_accumulator/i_acc_ctrl/*
add wave -group wrap -group top -group datapath -group denominator_accumulator -group accumulator_datapath /softex_tb/i_softex_wrap/i_top/i_datapath/i_denominator_accumulator/i_acc_datapath/*
add wave -group wrap -group top -group datapath -group denominator_accumulator -group accumulator_datapath -group denominator_inverter /softex_tb/i_softex_wrap/i_top/i_datapath/i_denominator_accumulator/i_acc_datapath/i_denominator_inverter/*