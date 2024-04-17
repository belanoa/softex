// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import hci_package::*;
import hwpe_stream_package::*;

module sfm_top #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT    = fpnew_pkg::FP16ALT    ,
    parameter int unsigned              DATA_WIDTH  = 128                   ,
    parameter int unsigned              N_CORES     = 8                          
) (
    input   logic                           clk_i   ,
    input   logic                           rst_ni  ,

    output  logic                           busy_o  ,
    output  logic [N_CORES - 1 : 0] [1 : 0] evt_o   ,

    hci_core_intf.master                    tcdm    ,
    hwpe_ctrl_intf_periph.slave             periph  
);

    localparam int unsigned WIDTH       = fpnew_pkg::fp_width(FPFORMAT);
    localparam int unsigned ACTUAL_DW   = DATA_WIDTH - 32;

    hci_streamer_flags_t        stream_in_flgs;
    hci_streamer_flags_t        stream_out_flgs;
    hci_streamer_ctrl_t         stream_in_ctrl;
    hci_streamer_ctrl_t         stream_out_ctrl;

    sfm_pkg::datapath_ctrl_t    datapath_ctrl;
    sfm_pkg::datapath_flags_t   datapath_flgs;

    hwpe_stream_intf_stream #(.DATA_WIDTH(DATA_WIDTH)) in_stream (.clk(clk_i));
    hwpe_stream_intf_stream #(.DATA_WIDTH(DATA_WIDTH)) out_stream (.clk(clk_i));

    logic [ACTUAL_DW / WIDTH - 1 : 0]   in_strb,
                                        out_strb;

    logic   clear;

    sfm_ctrl #(
        .N_CORES    (   N_CORES     ),
        .DATA_WIDTH (   ACTUAL_DW   )
    ) i_ctrl (
        .clk_i              (   clk_i           ),
        .rst_ni             (   rst_ni          ),
        .enable_i           (   '1              ),
        .in_stream_flags_i  (   stream_in_flgs  ),
        .out_stream_flags_i (   stream_out_flgs ),
        .datapath_flgs_i    (   datapath_flgs   ),
        .clear_o            (   clear           ),
        .busy_o             (   busy_o          ),
        .evt_o              (   evt_o           ),
        .in_stream_ctrl_o   (   stream_in_ctrl  ),
        .out_stream_ctrl_o  (   stream_out_ctrl ),
        .datapath_ctrl_o    (   datapath_ctrl   ),
        .periph             (   periph          )
    );

    sfm_datapath #(
        .IN_FPFORMAT        (   FPFORMAT            ),
        .ACC_FPFORMAT       (   fpnew_pkg::FP32     ),
        .VECT_WIDTH         (   ACTUAL_DW / WIDTH   ),
        .REG_POS            (   ),
        .ADD_REGS           (   ),
        .MUL_REGS           (   ),
        .MAX_REGS           (   ),
        .EXP_REGS           (   ),
        .FMA_REGS           (   ),
        .FACTOR_FIFO_DEPTH  (   ),
        .ADDEND_FIFO_DEPTH  (   )
    ) i_datapath (
        .clk_i      (   clk_i                                   ),
        .rst_ni     (   rst_ni                                  ),
        .clear_i    (   clear                                   ),
        .valid_i    (   in_stream.valid                         ),
        .ready_i    (   out_stream.ready                        ),
        .ctrl_i     (   datapath_ctrl                           ),
        .strb_i     (   in_strb                                 ),
        .data_i     (   in_stream.data [DATA_WIDTH - 33 : 0]    ),
        .valid_o    (   out_stream.valid                        ),
        .ready_o    (   in_stream.ready                         ),
        .flags_o    (   datapath_flgs                           ),
        .strb_o     (   out_strb                                ),
        .res_o      (   out_stream.data [DATA_WIDTH - 33 : 0]   )   
    );

    assign out_stream.data [DATA_WIDTH - 1 -: 32] = '0;

    always_comb begin : strb_assignment
        out_stream.strb = '0;

        for (int i = 0; i < ACTUAL_DW / WIDTH; i++) begin
            in_strb [i]                                         = &in_stream.strb[(WIDTH / 8) * i + 1 -: (WIDTH / 8)];
            out_stream.strb[(WIDTH / 8) * i + 1 -: (WIDTH / 8)] = {(WIDTH / 8){out_strb[i]}};
        end
    end
    
    sfm_streamer #(
        .DATA_WIDTH (   DATA_WIDTH  ),
        .ADDR_WIDTH ()
    ) i_streamer (
        .clk_i              (   clk_i           ),
        .rst_ni             (   rst_ni          ),
        .clear_i            (   clear           ),  
        .enable_i           (   '1              ), 
        .in_stream_ctrl_i   (   stream_in_ctrl  ), 
        .out_stream_ctrl_i  (   stream_out_ctrl ),
        .in_stream_flags_o  (   stream_in_flgs  ),
        .out_stream_flags_o (   stream_out_flgs ),
        .in_stream_o        (   in_stream       ),  
        .out_stream_i       (   out_stream      ), 
        .tcdm               (   tcdm            ) 
    );

endmodule