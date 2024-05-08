// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

import softex_pkg::*;
import fpnew_pkg::*;

module softex_fp_red_minmax #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = FPFORMAT_IN       ,
    parameter softex_pkg::regs_config_t REG_POS                 = DEFAULT_REG_POS   ,
    parameter int unsigned              NUM_REGS                = 0                 ,
    parameter int unsigned              VECT_WIDTH              = 1                 ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT)              
) (
    input   logic                                                           clk_i       ,
    input   logic                                                           rst_ni      ,
    input   logic                                                           clear_i     ,
    input   logic                                                           enable_i    ,
    input   logic                                                           valid_i     ,
    input   logic                                                           ready_i     ,
    input   logic                   [VECT_WIDTH - 1 : 0]                    strb_i      ,
    input   logic                   [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]    vect_i      ,
    input   softex_pkg::min_max_mode_t                                      mode_i      ,
    output  logic                   [WIDTH - 1 : 0]                         res_o       ,
    output  logic                                                           strb_o      ,
    output  logic                                                           valid_o     ,
    output  logic                                                           ready_o
);

    logic   minmax_strb;

    softex_pkg::min_max_mode_t mode;

    logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  vect;

    logic [VECT_WIDTH - 1 : 0]  strb;

    logic [WIDTH - 1 : 0]   minmax_res,
                            res;

    softex_pipeline #(
        .REG_POS    (   REG_POS     ),
        .NUM_REGS   (   NUM_REGS    ),
        .WIDTH_IN   (   WIDTH       ),
        .NUM_IN     (   VECT_WIDTH  ),
        .WIDTH_OUT  (   WIDTH       ),
        .NUM_OUT    (   1           )
    ) i_minmax_pipeline (
        .clk_i      (   clk_i       ),
        .rst_ni     (   rst_ni      ),
        .enable_i   (   enable_i    ),
        .clear_i    (   clear_i     ),
        .valid_i    (   valid_i     ),
        .ready_i    (   ready_i     ),
        .valid_o    (   valid_o     ),
        .ready_o    (   ready_o     ),
        .i_data_i   (   vect_i      ),
        .i_data_o   (   vect        ),
        .o_data_i   (   minmax_res  ),
        .o_data_o   (   res_o       ),
        .i_strb_i   (   strb_i      ),
        .i_strb_o   (   strb        ),
        .o_strb_i   (   minmax_strb ),
        .o_strb_o   (   strb_o      )
    );

    softex_pipeline #(
        .REG_POS    (   REG_POS     ),
        .NUM_REGS   (   NUM_REGS    ),
        .WIDTH_IN   (   1           ),
        .NUM_IN     (   1           ),
        .WIDTH_OUT  (   0           ),
        .NUM_OUT    (   0           )
    ) i_mode_pipeline (
        .clk_i      (   clk_i       ),
        .rst_ni     (   rst_ni      ),
        .enable_i   (   enable_i    ),
        .clear_i    (   clear_i     ),
        .valid_i    (   valid_i     ),
        .ready_i    (   ready_i     ),
        .valid_o    (               ),
        .ready_o    (               ),
        .i_data_i   (   mode_i      ),
        .i_data_o   (   {mode}      ),
        .o_data_i   (               ),
        .o_data_o   (               ),
        .i_strb_i   (   '1          ),
        .i_strb_o   (               ),
        .o_strb_i   (               ),
        .o_strb_o   (               )
    );


    softex_fp_minmax_rec #(
        .FPFORMAT   (   FPFORMAT    ),
        .N_INP      (   VECT_WIDTH  )
    ) minmax_tree (
        .op_i   (   vect        ),
        .strb_i (   strb        ),
        .mode_i (   mode        ),
        .res_o  (   minmax_res  ),
        .strb_o (   minmax_strb )
    );

endmodule