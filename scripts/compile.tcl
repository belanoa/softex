# This script was generated automatically by bender.
set ROOT "/home/abelano/CRYPT/sfm"

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/src/clk_rst_gen.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/src/rand_id_queue.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/src/rand_stream_mst.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/src/rand_synch_holdable_driver.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/src/rand_verif_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/src/signal_highlighter.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/src/sim_timeout.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/src/stream_watchdog.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/src/rand_synch_driver.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/src/rand_stream_slv.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/common_verification-f442e3d0b46bfb43/test/tb_clk_rst_gen.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/rtl/tc_sram.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/rtl/tc_sram_impl.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/rtl/tc_clk.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/deprecated/cluster_pwr_cells.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/deprecated/generic_memory.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/deprecated/generic_rom.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/deprecated/pad_functional.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/deprecated/pulp_buffer.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/deprecated/pulp_pwr_cells.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/tc_pwr.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/test/tb_tc_sram.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/deprecated/pulp_clock_gating_async.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/deprecated/cluster_clk_cells.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-643f450c638ffb6a/src/deprecated/pulp_clk_cells.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/include" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/binary_to_gray.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/include" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cb_filter_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cc_onehot.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cdc_reset_ctrlr_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cf_math_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/clk_int_div.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/delta_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/ecc_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/edge_propagator_tx.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/exp_backoff.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/fifo_v3.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/gray_to_binary.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/isochronous_4phase_handshake.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/isochronous_spill_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/lfsr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/lfsr_16bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/lfsr_8bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/lossy_valid_to_stream.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/mv_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/onehot_to_bin.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/plru_tree.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/popcount.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/rr_arb_tree.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/rstgen_bypass.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/serial_deglitch.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/shift_reg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/shift_reg_gated.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/spill_register_flushable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_demux.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_fork.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_intf.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_join_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_mux.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_throttle.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/sub_per_hash.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/sync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/sync_wedge.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/unread.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/read.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/addr_decode_dync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cdc_2phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cdc_4phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/clk_int_div_static.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/addr_decode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/addr_decode_napot.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/multiaddr_decode.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/include" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cb_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cdc_fifo_2phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/clk_mux_glitch_free.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/ecc_decode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/ecc_encode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/edge_detect.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/lzc.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/max_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/rstgen.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/spill_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_delay.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_fork_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_join.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cdc_reset_ctrlr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cdc_fifo_gray.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/fall_through_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/id_queue.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_to_mem.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_arbiter_flushable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_fifo_optimal_wrap.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_xbar.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cdc_fifo_gray_clearable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/cdc_2phase_clearable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/mem_to_banks_detailed.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_arbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/stream_omega_net.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/mem_to_banks.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/include" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/sram.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/include" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/addr_decode_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/cb_filter_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/cdc_2phase_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/cdc_2phase_clearable_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/cdc_fifo_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/cdc_fifo_clearable_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/fifo_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/graycode_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/id_queue_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/popcount_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/rr_arb_tree_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/stream_test.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/stream_register_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/stream_to_mem_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/sub_per_hash_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/isochronous_crossing_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/stream_omega_net_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/stream_xbar_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/clk_int_div_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/clk_int_div_static_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/clk_mux_glitch_free_tb.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/test/lossy_valid_to_stream_tb.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/include" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/clock_divider_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/clk_div.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/find_first_one.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/generic_LFSR_8bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/generic_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/prioarbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/pulp_sync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/pulp_sync_wedge.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/rrarbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/clock_divider.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/fifo_v2.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/deprecated/fifo_v1.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/edge_propagator_ack.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/edge_propagator.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/src/edge_propagator_rx.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/include" \
    "$ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-f883e21afc9e4be2/hdl/defs_div_sqrt_mvp.sv" \
    "$ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-f883e21afc9e4be2/hdl/iteration_div_sqrt_mvp.sv" \
    "$ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-f883e21afc9e4be2/hdl/control_mvp.sv" \
    "$ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-f883e21afc9e4be2/hdl/norm_div_sqrt_mvp.sv" \
    "$ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-f883e21afc9e4be2/hdl/preprocess_mvp.sv" \
    "$ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-f883e21afc9e4be2/hdl/nrbd_nrsc_mvp.sv" \
    "$ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-f883e21afc9e4be2/hdl/div_sqrt_top_mvp.sv" \
    "$ROOT/.bender/git/checkouts/fpu_div_sqrt_mvp-f883e21afc9e4be2/hdl/div_sqrt_mvp_wrapper.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/include" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_pkg.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_cast_multi.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_classifier.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_ctrl.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_ff1.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_pack_single.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_prepare.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_round_single.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_special.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_srt_single.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_top.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_dp.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_frbus.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_src_type.v" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_divsqrt_th_32.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_divsqrt_multi.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_fma.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_fma_multi.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_sdotp_multi.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_sdotp_multi_wrapper.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_noncomp.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_opgroup_block.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_opgroup_fmt_slice.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_opgroup_multifmt_slice.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_rounding.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/lfsr_sr.sv" \
    "$ROOT/.bender/git/checkouts/fpnew-00a887d6a03a62e2/src/fpnew_top.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/include" \
    "$ROOT/rtl/sfm_pkg.sv" \
    "$ROOT/rtl/sfm_fp_red_minmax.sv" \
    "$ROOT/rtl/sfm_fp_red_sum.sv" \
    "$ROOT/rtl/sfm_pipeline.sv" \
    "$ROOT/rtl/sfm_delay.sv" \
    "$ROOT/rtl/sfm_fp_glob_minmax.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -suppress 2583 -suppress 13314 -suppress 8386 \
    +define+TARGET_RTL \
    +define+TARGET_SFM_SIM \
    +define+TARGET_SIMULATION \
    +define+TARGET_TEST \
    +define+TARGET_VSIM \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-59f890505a6ae11b/include" \
    "$ROOT/tb/sfm_fp_vect_minmax_tb.sv" \
    "$ROOT/tb/sfm_fp_vect_sum_tb.sv" \
    "$ROOT/tb/sfm_fp_glob_minmax_tb.sv" \
}]} {return 1}

