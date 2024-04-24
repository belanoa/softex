// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

`include "sfm_macros.svh"

import sfm_pkg::*;

module sfm_fp_glob_minmax #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT    = FPFORMAT_IN       ,
    parameter sfm_pkg::regs_config_t    REG_POS     = DEFAULT_REG_POS   ,
    parameter int unsigned              NUM_REGS    = 0                 ,
    parameter int unsigned              VECT_WIDTH  = 1                 ,

    localparam int unsigned WIDTH   = fpnew_pkg::fp_width(FPFORMAT)   
) (
    input   logic                                       clk_i           ,
    input   logic                                       rst_ni          ,
    input   logic                                       clear_i         ,
    input   logic                                       enable_i        ,
    input   logic                                       valid_i         ,
    input   logic                                       ready_i         ,
    input   sfm_pkg::min_max_mode_t                     operation_i     ,
    input   logic [VECT_WIDTH - 1 : 0]                  strb_i          ,
    input   logic [VECT_WIDTH - 1 : 0] [WIDTH - 1 : 0]  vect_i          ,
    input   logic [WIDTH - 1 : 0]                       load_i          ,
    input   logic                                       load_en_i       ,
    output  logic [WIDTH - 1 : 0]                       cur_minmax_o    ,
    output  logic [WIDTH - 1 : 0]                       new_minmax_o    ,
    output  logic                                       new_flg_o       ,
    output  logic                                       valid_o         ,
    output  logic                                       ready_o
);

    /* This module keeps track of the maximum value and *
     * signals the datapath when this value is updated  */

    logic [WIDTH - 1 : 0]   minmax_q,
                            vect_minmax;

    logic   minmax_strb,
            minmax_valid,
            new_flg;

    logic   o_valid_q;

    assign valid_o = o_valid_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin : o_valid_register
        if (~rst_ni) begin
            o_valid_q <= '0;
        end else begin
            if (clear_i) begin
                o_valid_q <= '0;
            end else if (minmax_valid) begin
                o_valid_q <= '1;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : minmax_register
        if (~rst_ni) begin
            minmax_q <= (operation_i == sfm_pkg::MAX) ? `NEG_INFTY(FPFORMAT) : `POS_INFTY(FPFORMAT);
        end else begin
            if (clear_i) begin
                minmax_q <= (operation_i == sfm_pkg::MAX) ? `NEG_INFTY(FPFORMAT) : `POS_INFTY(FPFORMAT);
            end else if (load_en_i) begin
                minmax_q <= load_i;
            end else if (minmax_valid & new_flg & ready_i) begin
                minmax_q <= vect_minmax;
            end
        end
    end

    sfm_fp_red_minmax #(
        .FPFORMAT   (   FPFORMAT    ),
        .REG_POS    (   REG_POS     ),
        .NUM_REGS   (   NUM_REGS    ),
        .VECT_WIDTH (   VECT_WIDTH  )                                     
    ) i_minmax_reduction (
        .clk_i      (   clk_i           ),
        .rst_ni     (   rst_ni          ),
        .clear_i    (   clear_i         ),
        .enable_i   (   enable_i        ),
        .valid_i    (   valid_i         ),
        .ready_i    (   ready_i         ),
        .strb_i     (   strb_i          ),
        .vect_i     (   vect_i          ),
        .mode_i     (   operation_i     ),
        .res_o      (   vect_minmax     ),
        .strb_o     (   minmax_strb     ),
        .valid_o    (   minmax_valid    ),
        .ready_o    (   ready_o         )
    );

    assign new_flg      = minmax_strb & ((operation_i == sfm_pkg::MAX) ? `FP_GT(vect_minmax, minmax_q, FPFORMAT) : `FP_LT(vect_minmax, minmax_q, FPFORMAT));

    assign cur_minmax_o = minmax_q;
    assign new_minmax_o = new_flg ? vect_minmax : minmax_q;
    assign new_flg_o    = new_flg;

endmodule