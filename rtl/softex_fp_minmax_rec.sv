// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

`include "softex_macros.svh"


module softex_fp_minmax_rec import softex_pkg::*; #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT    = FPFORMAT_IN   ,
    parameter int unsigned              N_INP       = 1             ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT)
) (
    input   logic [N_INP - 1 : 0] [WIDTH - 1 : 0]   op_i    ,
    input   logic [N_INP - 1 : 0]                   strb_i  ,
    input   softex_pkg::min_max_mode_t              mode_i  ,
    output  logic [WIDTH - 1 : 0]                   res_o   ,
    output  logic                                   strb_o
);

    //The vector to be reduced is split into 2 smaller vectors (A and B)
    //which will be reduced separately

    localparam int unsigned A_WIDTH = (N_INP + 1) / 2;
    localparam int unsigned B_WIDTH = N_INP - A_WIDTH;

    logic [A_WIDTH - 1 : 0] [WIDTH - 1 : 0] a;
    logic [B_WIDTH - 1 : 0] [WIDTH - 1 : 0] b;

    logic [WIDTH - 1 : 0]   res_a,
                            res_b;

    logic   o_strb_a,
            o_strb_b;

    logic [A_WIDTH - 1 : 0] i_strb_a;
    logic [B_WIDTH - 1 : 0] i_strb_b;

    if (N_INP != 1) begin
        assign a = op_i [A_WIDTH - 1 : 0];
        assign b = op_i [N_INP - 1 -: B_WIDTH];

        assign i_strb_a = strb_i [A_WIDTH - 1 : 0];
        assign i_strb_b = strb_i [N_INP - 1 -: B_WIDTH];
    end

    if (N_INP == 1) begin : gen_identity
        //If the module is instantiated with only one input
        //no operation has to be performed

        assign res_o    = op_i;
        assign strb_o   = strb_i;
    end else if (N_INP == 2) begin : gen_minmax
        //If we only have 2 inputs we just compare them

        assign res_o    = (&strb_i == 1) ? ((mode_i == softex_pkg::MAX) ? (`FP_GT(a[0], b[0], FPFORMAT) ? a : b) : (`FP_LT(a[0], b[0], FPFORMAT) ? a : b)) : ((i_strb_a == 1) ? a : b);
        assign strb_o   = |strb_i;
    end else begin : gen_recursion
        //A and B are redduced separately and the results are compared

         softex_fp_minmax_rec #(
            .FPFORMAT   (   FPFORMAT    ),
            .N_INP      (   A_WIDTH     )
        ) a_minmax (
            .op_i   (   a           ),
            .strb_i (   i_strb_a    ),
            .mode_i (   mode_i      ),
            .res_o  (   res_a       ),
            .strb_o (   o_strb_a    )
        );

        softex_fp_minmax_rec #(
            .FPFORMAT   (   FPFORMAT    ),
            .N_INP      (   B_WIDTH     )
        ) b_minmax (
            .op_i   (   b           ),
            .strb_i (   i_strb_b    ),
            .mode_i (   mode_i      ),
            .res_o  (   res_b       ),
            .strb_o (   o_strb_b    )
        );

        assign res_o    = (o_strb_a & o_strb_b) ? ((mode_i == softex_pkg::MAX) ? (`FP_GT(res_a, res_b, FPFORMAT) ? res_a : res_b) : (`FP_LT(res_a, res_b, FPFORMAT) ? res_a : res_b)) : ((o_strb_a == 1) ? res_a : res_b);
        assign strb_o   = o_strb_a | o_strb_b;
    end

endmodule