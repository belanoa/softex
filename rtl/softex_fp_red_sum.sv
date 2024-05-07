// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

`include "softex_macros.svh"

import softex_pkg::*;
import fpnew_pkg::*;

module softex_fp_red_sum #(
    parameter fpnew_pkg::fp_format_e    IN_FPFORMAT             = FPFORMAT_IN       ,
    parameter fpnew_pkg::fp_format_e    ACC_FPFORMAT            = FPFORMAT_ACC      ,
    parameter softex_pkg::regs_config_t    REG_POS                 = DEFAULT_REG_POS   ,
    parameter int unsigned              NUM_REGS                = 0                 ,
    parameter int unsigned              VECT_WIDTH              = 1                 ,
    parameter type                      TAG_TYPE                = logic             ,

    localparam int unsigned IN_WIDTH   = fpnew_pkg::fp_width(IN_FPFORMAT)   ,
    localparam int unsigned ACC_WIDTH  = fpnew_pkg::fp_width(ACC_FPFORMAT)
) (
    input   logic                                           clk_i       ,
    input   logic                                           rst_ni      ,
    input   logic                                           clear_i     ,
    input   logic                                           enable_i    ,
    input   logic                                           valid_i     ,
    input   logic                                           ready_i     ,
    input   fpnew_pkg::roundmode_e                          mode_i      ,
    input   logic [VECT_WIDTH - 1 : 0]                      strb_i      ,
    input   logic [VECT_WIDTH - 1 : 0] [IN_WIDTH - 1 : 0]   vect_i      ,
    input   TAG_TYPE                                        tag_i       ,
    output  logic [ACC_WIDTH - 1 : 0]                       res_o       ,
    output  logic                                           strb_o      ,
    output  logic                                           valid_o     ,
    output  logic                                           ready_o     ,
    output  TAG_TYPE                                        tag_o       ,
    output  logic                                           busy_o      
);

    localparam int unsigned ZEROPAD = ACC_WIDTH - IN_WIDTH;

    logic [VECT_WIDTH - 1 : 0] [ACC_WIDTH - 1 : 0]  cast_vect;


    for (genvar i = 0; i < VECT_WIDTH; i++) begin : input_cast
        fpnew_cast_multi #(
            .FpFmtConfig    (   `FMT_TO_CONF(IN_FPFORMAT, ACC_FPFORMAT) ),
            .IntFmtConfig   (   '0                                      ),
            .NumPipeRegs    (   0                                       ),
            .PipeConfig     (   fpnew_pkg::BEFORE                       ),
            .TagType        (   logic                                   ),
            .AuxType        (   logic                                   )
        ) i_vect_cast (
            .clk_i              (   clk_i                           ),
            .rst_ni             (   rst_ni                          ),
            .operands_i         (   {{ZEROPAD{1'b0}}, vect_i [i]}   ),
            .is_boxed_i         (   '1                              ),
            .rnd_mode_i         (   fpnew_pkg::RNE                  ),
            .op_i               (   fpnew_pkg::F2F                  ),
            .op_mod_i           (   '0                              ),
            .src_fmt_i          (   IN_FPFORMAT                     ),
            .dst_fmt_i          (   ACC_FPFORMAT                    ),
            .int_fmt_i          (   fpnew_pkg::INT8                 ),
            .tag_i              (   '0                              ),
            .mask_i             (   '0                              ),
            .aux_i              (   '0                              ),
            .in_valid_i         (   '1                              ),
            .in_ready_o         (                                   ),
            .flush_i            (   '0                              ),
            .result_o           (   cast_vect [i]                   ),
            .status_o           (                                   ),
            .extension_bit_o    (                                   ),
            .tag_o              (                                   ),
            .mask_o             (                                   ),
            .aux_o              (                                   ),
            .out_valid_o        (                                   ),
            .out_ready_i        (   '1                              ),
            .busy_o             (                                   )
        );
    end

    softex_fp_add_rec #(
        .FPFORMAT   (   ACC_FPFORMAT    ),    
        .N_INP      (   VECT_WIDTH      ),       
        .NUM_REGS   (   NUM_REGS        ),    
        .REG_POS    (   REG_POS         ),
        .TAG_TYPE   (   TAG_TYPE        ) 
    ) i_add_rec (
        .clk_i      (   clk_i               ),
        .rst_ni     (   rst_ni              ),
        .clear_i    (   clear_i             ),
        .valid_i    (   valid_i             ),
        .ready_i    (   ready_i & enable_i  ),
        .op_i       (   cast_vect           ),
        .strb_i     (   strb_i              ),
        .mode_i     (   mode_i              ),
        .tag_i      (   tag_i               ),
        .ready_o    (   ready_o             ),
        .valid_o    (   valid_o             ),
        .res_o      (   res_o               ),
        .strb_o     (   strb_o              ),
        .tag_o      (   tag_o               ),
        .busy_o     (   busy_o              )
    );

endmodule