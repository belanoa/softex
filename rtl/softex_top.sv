// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
// Yvan Tortorella <yvan.tortorella@unibo.it>
//

`include "hci_helpers.svh"

import hci_package::*;
import hwpe_stream_package::*;
import softex_pkg::*;

module softex_top #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT    = FPFORMAT_IN   ,
    parameter int unsigned              INT_WIDTH   = INT_W         ,
    parameter int unsigned              N_CORES     = 8             ,
    parameter hci_size_parameter_t `HCI_SIZE_PARAM(Tcdm) = '0
) (
    input   logic                           clk_i   ,
    input   logic                           rst_ni  ,

    output  logic                           busy_o  ,
    output  logic [N_CORES - 1 : 0] [1 : 0] evt_o   ,

    hci_core_intf.initiator                 tcdm    ,
    hwpe_ctrl_intf_periph.slave             periph  
);

    localparam int unsigned WIDTH       = fpnew_pkg::fp_width(FPFORMAT);
    localparam int unsigned ACTUAL_DW   = `HCI_SIZE_GET_DW(Tcdm) - 32;

    hci_streamer_flags_t    stream_in_flgs;
    hci_streamer_flags_t    stream_out_flgs;
    hci_streamer_flags_t    slot_in_flgs;
    hci_streamer_flags_t    slot_out_flgs;
    hci_streamer_flags_t    a_in_stream_flags;
    hci_streamer_flags_t    b_in_stream_flags;

    hci_streamer_ctrl_t     stream_in_ctrl;
    hci_streamer_ctrl_t     stream_out_ctrl;
    hci_streamer_ctrl_t     slot_in_ctrl;
    hci_streamer_ctrl_t     slot_out_ctrl;
    hci_streamer_ctrl_t     a_in_stream_ctrl;
    hci_streamer_ctrl_t     b_in_stream_ctrl;

    ab_addressgen_ctrl_t    a_addgen_ctrl,
                            b_addgen_ctrl;

    x_buffer_ctrl_t         x_buffer_ctrl;
    ab_buffer_ctrl_t        a_buffer_ctrl,
                            b_buffer_ctrl;

    cast_ctrl_t             in_cast_ctrl;
    cast_ctrl_t             out_cast_ctrl;

    datapath_ctrl_t         datapath_ctrl;
    datapath_flags_t        datapath_flgs;

    ab_buffer_flags_t       a_buffer_flgs, b_buffer_flgs;
    x_buffer_flags_t        x_buffer_flgs;

    slot_regfile_ctrl_t     slot_regfile_ctrl;

    slot_t                  state_slot;

    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW))   in_stream       (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW))   out_stream      (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW))   slot_in_stream  (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW))   slot_out_stream (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW))   a_in_stream     (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW))   b_in_stream    (.clk(clk_i));

    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW))   out_fifo_d      (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW))   in_fifo_q       (.clk(clk_i));

    hwpe_stream_intf_stream #(.DATA_WIDTH(WIDTH+1)) a_weight_q (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(WIDTH+1)) b_weight_q (.clk(clk_i));

    logic   clear;

    softex_ctrl #(
        .N_CORES    (   N_CORES     ),
        .DATA_WIDTH (   ACTUAL_DW   )
    ) i_ctrl (
        .clk_i                  (   clk_i               ),
        .rst_ni                 (   rst_ni              ),
        .enable_i               (   '1                  ),
        .in_stream_flags_i      (   stream_in_flgs      ),
        .out_stream_flags_i     (   stream_out_flgs     ),
        .datapath_flgs_i        (   datapath_flgs       ),
        .state_slot_i           (   state_slot          ),
        .clear_o                (   clear               ),
        .busy_o                 (   busy_o              ),
        .evt_o                  (   evt_o               ),
        .in_stream_ctrl_o       (   stream_in_ctrl      ),
        .out_stream_ctrl_o      (   stream_out_ctrl     ),
        .x_buffer_ctrl_o        (   x_buffer_ctrl       ),
        .a_buffer_ctrl_o        (   a_buffer_ctrl       ),
        .b_buffer_ctrl_o        (   b_buffer_ctrl       ),
        .a_addressgen_ctrl_o    (   a_addgen_ctrl       ),
        .b_addressgen_ctrl_o    (   b_addgen_ctrl       ),
        .datapath_ctrl_o        (   datapath_ctrl       ),
        .slot_ctrl_o            (   slot_regfile_ctrl   ),
        .in_cast_ctrl_o         (   in_cast_ctrl        ),
        .out_cast_ctrl_o        (   out_cast_ctrl       ),
        .periph                 (   periph              )
    );

    softex_slot_regfile #(
        .DATA_WIDTH (   ACTUAL_DW  )
    ) i_slot_regfile (
        .clk_i          (   clk_i               ),
        .rst_ni         (   rst_ni              ),
        .clear_i        (   clear               ),
        .ctrl_i         (   slot_regfile_ctrl   ),
        .slot_o         (   state_slot          ),
        .store_ctrl_o   (   slot_out_ctrl       ),
        .load_ctrl_o    (   slot_in_ctrl        ),
        .store_o        (   slot_out_stream     ),
        .load_i         (   slot_in_stream      )
    );

    if (NUM_REGS_ROW_ACC != 1) begin : generate_loop_buffer
        softex_x_buffer #(
            .DATA_WIDTH (   ACTUAL_DW   ),
            .LATCH_BUFFER   (   0       )
        ) i_x_buffer (
            .clk_i      (   clk_i           ),
            .rst_ni     (   rst_ni          ),
            .clear_i    (   clear           ),
            .ctrl_i     (   x_buffer_ctrl   ),
            .flags_o    (                   ),
            .buffer_i   (   in_stream       ),
            .buffer_o   (   in_fifo_q       )
        );
    end else begin : generate_no_loop_buffer
        softex_x_buffer_single #(
            .DATA_WIDTH     (   ACTUAL_DW   ),
            .DEPTH          (   2           ),
            .LATCH_BUFFER   (   0           )
        ) i_x_buffer (
            .clk_i      (   clk_i           ),
            .rst_ni     (   rst_ni          ),
            .clear_i    (   clear           ),
            .ctrl_i     (   x_buffer_ctrl   ),
            .flags_o    (                   ),
            .buffer_i   (   in_stream       ),
            .buffer_o   (   in_fifo_q       )
        );
    end

    softex_ab_buffer #(
        .N_ELEMS    (   16   )
    ) i_a_buffer (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .clear_i    (   clear           ),
        .ctrl_i     (   a_buffer_ctrl   ),
        .flags_o    (                   ),
        .buffer_i   (   a_in_stream     ),
        .buffer_o   (   a_weight_q      )
    );

    softex_ab_buffer #(
        .N_ELEMS    (   16  )
    ) i_b_buffer (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .clear_i    (   clear           ),
        .ctrl_i     (   b_buffer_ctrl   ),
        .flags_o    (                   ),
        .buffer_i   (   b_in_stream     ),
        .buffer_o   (   b_weight_q      )
    );

    softex_ab_addressgen #(
        .N_ELEMS    (   16   )
    ) i_a_addressgen (
        .clk_i          (   clk_i               ),
        .rst_ni         (   rst_ni              ),
        .clear_i        (   clear               ),
        .ctrl_i         (   a_addgen_ctrl       ),
        .stream_flags_i (   a_in_stream_flags   ),
        .stream_ctrl_o  (   a_in_stream_ctrl    )
    );

    softex_ab_addressgen #(
        .N_ELEMS    (   16   )
    ) i_b_addressgen (
        .clk_i          (   clk_i               ),
        .rst_ni         (   rst_ni              ),
        .clear_i        (   clear               ),
        .ctrl_i         (   b_addgen_ctrl       ),
        .stream_flags_i (   b_in_stream_flags   ),
        .stream_ctrl_o  (   b_in_stream_ctrl    )
    );

    softex_datapath #(
        .DATA_WIDTH     (   ACTUAL_DW           ),
        .IN_FPFORMAT    (   FPFORMAT            ),
        .VECT_WIDTH     (   ACTUAL_DW / WIDTH   )
    ) i_datapath (
        .clk_i      (   clk_i                                   ),
        .rst_ni     (   rst_ni                                  ),
        .clear_i    (   clear                                   ),
        .ctrl_i     (   datapath_ctrl                           ),
        .flags_o    (   datapath_flgs                           ),
        .x_stream_i (   in_fifo_q                               ),
        .a_stream_i (   a_weight_q                              ),
        .b_stream_i (   b_weight_q                              ),
        .stream_o   (   out_fifo_d                              )   
    );

    hwpe_stream_fifo #(
        .DATA_WIDTH (   ACTUAL_DW  ),
        .FIFO_DEPTH (   2           )
    ) i_out_fifo (
        .clk_i      (   clk_i       ),
        .rst_ni     (   rst_ni      ),
        .clear_i    (   clear       ),
        .flags_o    (               ),
        .push_i     (   out_fifo_d  ),
        .pop_o      (   out_stream  )
    );

    softex_streamer #(
        .`HCI_SIZE_PARAM(Tcdm) ( `HCI_SIZE_PARAM(Tcdm)),
        .ACTUAL_DW ( ACTUAL_DW )
    ) i_streamer (
        .clk_i                  (   clk_i               ),
        .rst_ni                 (   rst_ni              ),
        .clear_i                (   clear               ),  
        .enable_i               (   '1                  ), 
        .in_stream_ctrl_i       (   stream_in_ctrl      ), 
        .out_stream_ctrl_i      (   stream_out_ctrl     ),
        .slot_in_ctrl_i         (   slot_in_ctrl        ), 
        .slot_out_ctrl_i        (   slot_out_ctrl       ),
        .a_in_stream_ctrl_i     (   a_in_stream_ctrl    ),
        .b_in_stream_ctrl_i     (   b_in_stream_ctrl    ),
        .in_cast_i              (   in_cast_ctrl        ),
        .out_cast_i             (   out_cast_ctrl       ),
        .in_stream_flags_o      (   stream_in_flgs      ),
        .out_stream_flags_o     (   stream_out_flgs     ),
        .a_in_stream_flags_o    (   a_in_stream_flags   ),
        .b_in_stream_flags_o    (   b_in_stream_flags   ),
        .slot_in_flags_o        (   slot_in_flgs        ),
        .slot_out_flags_o       (   slot_out_flgs       ),
        .in_stream_o            (   in_stream           ),  
        .out_stream_i           (   out_stream          ),
        .slot_in_stream_o       (   slot_in_stream      ),  
        .slot_out_stream_i      (   slot_out_stream     ), 
        .a_in_stream_o          (   a_in_stream         ),
        .b_in_stream_o          (   b_in_stream         ),
        .tcdm                   (   tcdm                ) 
    );

endmodule
