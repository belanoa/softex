// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import hci_package::*;
import hwpe_stream_package::*;
import softex_pkg::*;

module softex_top #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT    = FPFORMAT_IN   ,
    parameter int unsigned              INT_WIDTH   = INT_W         ,
    parameter int unsigned              DATA_WIDTH  = DATA_W        ,
    parameter int unsigned              N_CORES     = 8                          
) (
    input   logic                           clk_i   ,
    input   logic                           rst_ni  ,

    output  logic                           busy_o  ,
    output  logic [N_CORES - 1 : 0] [1 : 0] evt_o   ,

    hci_core_intf.initiator                 tcdm    ,
    hwpe_ctrl_intf_periph.slave             periph  
);

    localparam int unsigned WIDTH       = fpnew_pkg::fp_width(FPFORMAT);
    localparam int unsigned ACTUAL_DW   = DATA_WIDTH - 32;

    hci_streamer_flags_t    stream_in_flgs;
    hci_streamer_flags_t    stream_out_flgs;
    hci_streamer_flags_t    slot_in_flgs;
    hci_streamer_flags_t    slot_out_flgs;

    hci_streamer_ctrl_t     stream_in_ctrl;
    hci_streamer_ctrl_t     stream_out_ctrl;
    hci_streamer_ctrl_t     slot_in_ctrl;
    hci_streamer_ctrl_t     slot_out_ctrl;

    cast_ctrl_t             in_cast_ctrl;
    cast_ctrl_t             out_cast_ctrl;

    datapath_ctrl_t         datapath_ctrl;
    datapath_flags_t        datapath_flgs;

    slot_regfile_ctrl_t     slot_regfile_ctrl;

    slot_t                  state_slot;

    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW)) in_stream        (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW)) out_stream       (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW)) slot_in_stream   (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(ACTUAL_DW)) slot_out_stream  (.clk(clk_i));

    logic   clear;

    softex_ctrl #(
        .N_CORES    (   N_CORES     ),
        .DATA_WIDTH (   ACTUAL_DW   )
    ) i_ctrl (
        .clk_i              (   clk_i               ),
        .rst_ni             (   rst_ni              ),
        .enable_i           (   '1                  ),
        .in_stream_flags_i  (   stream_in_flgs      ),
        .out_stream_flags_i (   stream_out_flgs     ),
        .datapath_flgs_i    (   datapath_flgs       ),
        .state_slot_i       (   state_slot          ),
        .clear_o            (   clear               ),
        .busy_o             (   busy_o              ),
        .evt_o              (   evt_o               ),
        .in_stream_ctrl_o   (   stream_in_ctrl      ),
        .out_stream_ctrl_o  (   stream_out_ctrl     ),
        .datapath_ctrl_o    (   datapath_ctrl       ),
        .slot_ctrl_o        (   slot_regfile_ctrl   ),
        .in_cast_ctrl_o     (   in_cast_ctrl        ),
        .out_cast_ctrl_o    (   out_cast_ctrl       ),
        .periph             (   periph              )
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

    softex_datapath #(
        .DATA_WIDTH         (   ACTUAL_DW           ),
        .IN_FPFORMAT        (   FPFORMAT            ),
        .VECT_WIDTH         (   ACTUAL_DW / WIDTH   )
    ) i_datapath (
        .clk_i      (   clk_i                                   ),
        .rst_ni     (   rst_ni                                  ),
        .clear_i    (   clear                                   ),
        .ctrl_i     (   datapath_ctrl                           ),
        .flags_o    (   datapath_flgs                           ),
        .stream_i   (   in_stream                               ),
        .stream_o   (   out_stream                              )   
    );

    softex_streamer #(
        .DATA_WIDTH (   DATA_WIDTH  )
    ) i_streamer (
        .clk_i              (   clk_i           ),
        .rst_ni             (   rst_ni          ),
        .clear_i            (   clear           ),  
        .enable_i           (   '1              ), 
        .in_stream_ctrl_i   (   stream_in_ctrl  ), 
        .out_stream_ctrl_i  (   stream_out_ctrl ),
        .slot_in_ctrl_i     (   slot_in_ctrl    ), 
        .slot_out_ctrl_i    (   slot_out_ctrl   ),
        .in_cast_i          (   in_cast_ctrl    ),
        .out_cast_i         (   out_cast_ctrl   ),
        .in_stream_flags_o  (   stream_in_flgs  ),
        .out_stream_flags_o (   stream_out_flgs ),
        .slot_in_flags_o    (   slot_in_flgs    ),
        .slot_out_flags_o   (   slot_out_flgs   ),
        .in_stream_o        (   in_stream       ),  
        .out_stream_i       (   out_stream      ),
        .slot_in_stream_o   (   slot_in_stream  ),  
        .slot_out_stream_i  (   slot_out_stream ), 
        .tcdm               (   tcdm            ) 
    );

endmodule